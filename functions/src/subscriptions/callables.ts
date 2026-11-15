/**
 * Subscription callables (M10, FR-076 to FR-083, FR-101, FR-106, §5.5).
 *
 * Owner: `requestUpgrade`, `setHiddenOverLimit` (swap hidden items, or
 * downgrade to Free choosing what to hide).
 * Admin (TOTP, audit-logged): `recordPaymentAndActivate`,
 * `changeSubscription` (extend / modify / downgrade, with a reason),
 * `closeUpgradeRequest`, `adminListUpgradeRequests`.
 *
 * No online payments in the MVP: payments are recorded as data with a
 * `provider` field (FR-083), so a gateway can be added in Phase 4.
 */
import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";
import { z } from "zod";

import { writeAudit } from "../lib/audit";
import { assertAdmin, assertOwner, type CallerAuth , assertSignedIn } from "../lib/auth";
import { appError } from "../lib/errors";
import { getPlanFeatures, restaurantPlanFeatures } from "../lib/plan-limits";
import { parseInput } from "../lib/validation";
import { applyPlanLimits, clearHiddenOverLimit } from "./apply-limits";
import { queueOwnerMail } from "./mail";
import { freeSubscription, isPaid, subscriptionFrom, type Subscription } from "./model";

type Data = Record<string, unknown>;

const id = z.string().min(1).max(128).regex(/^[A-Za-z0-9_-]+$/);
const planIdSchema = z.string().regex(/^[A-Za-z0-9_-]{1,64}$/);
const isoDate = z.string().datetime({ offset: true }).or(z.string().regex(/^\d{4}-\d{2}-\d{2}$/));

export const PAYMENT_METHODS = ["bank-transfer", "upi", "cash", "cheque", "card", "other"] as const;

/** Stored form of a subscription (Timestamps). */
export function subscriptionDoc(s: Subscription): Data {
  const ts = (d: Date | null) => (d ? Timestamp.fromDate(d) : null);
  return {
    status: s.status,
    planId: s.planId,
    billing: s.billing,
    startAt: ts(s.startAt),
    expiresAt: ts(s.expiresAt),
    graceEndsAt: ts(s.graceEndsAt),
    remindersSent: s.remindersSent,
  };
}

const toDate = (s: string) => new Date(s.length === 10 ? `${s}T00:00:00Z` : s);

async function planOrThrow(db: Firestore, planId: string): Promise<Data> {
  const p = await db.doc(`plans/${planId}`).get();
  if (!p.exists && planId !== "free" && planId !== "pro") throw appError("not-found", "Unknown plan.", { planId });
  return p.data() ?? { name: planId === "pro" ? "Pro" : "Free", isFree: planId === "free" };
}

// ---- owner: requestUpgrade ---------------------------------------------------

export const requestUpgradeSchema = z
  .object({ restaurantId: id, planId: planIdSchema, billing: z.enum(["monthly", "annual"]) })
  .strict();

/**
 * Callable `requestUpgrade` (FR-106, §5.5 step 1): one open request at a
 * time, kept on the root as `pendingUpgradeRequestId`.
 */
export async function requestUpgrade(db: Firestore, auth: CallerAuth | undefined | null, data: unknown): Promise<{ requestId: string }> {
  assertSignedIn(auth); // before input checks: anonymous callers learn nothing (M13)
  const input = parseInput(requestUpgradeSchema, data);
  const owner = await assertOwner(auth, input.restaurantId, { db });
  const plan = await planOrThrow(db, input.planId);
  if (plan.isFree === true) throw appError("invalid-input", "Pick a paid plan.");
  const root = db.doc(`restaurants/${input.restaurantId}`);
  return db.runTransaction(async (tx) => {
    const r = (await tx.get(root)).data() as Data;
    if (typeof r.pendingUpgradeRequestId === "string") {
      throw appError("request-pending", "An upgrade request is already open.", { requestId: r.pendingUpgradeRequestId });
    }
    const sub = subscriptionFrom(r.subscription, r.planId);
    if (sub.status === "active" && r.planId === input.planId) throw appError("already-on-plan", "Already on this plan.");
    const ref = db.collection("upgradeRequests").doc();
    tx.create(ref, {
      restaurantId: input.restaurantId,
      restaurantName: r.name ?? "",
      ownerEmail: r.ownerEmail ?? null,
      ownerMobile: r.ownerMobile ?? null,
      country: r.country ?? null,
      currency: r.currency ?? null,
      currentPlanId: r.planId ?? "free",
      requestedPlanId: input.planId,
      billing: input.billing,
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      requestedBy: owner.uid,
    });
    tx.update(root, { pendingUpgradeRequestId: ref.id });
    await writeAudit(
      {
        actorUid: owner.uid,
        actorRole: "owner",
        action: "subscription.requestUpgrade",
        restaurantId: input.restaurantId,
        target: `upgradeRequests/${ref.id}`,
        details: { planId: input.planId, billing: input.billing },
      },
      { db: db as never, transaction: tx },
    );
    return { requestId: ref.id };
  });
}

// ---- admin: recordPaymentAndActivate ----------------------------------------

export const recordPaymentSchema = z
  .object({
    restaurantId: id,
    planId: planIdSchema,
    billing: z.enum(["monthly", "annual"]),
    amountMinor: z.number().int().positive().max(1_000_000_000_000),
    currency: z.string().regex(/^[A-Z]{3}$/),
    method: z.enum(PAYMENT_METHODS),
    reference: z.string().trim().min(1).max(200),
    paidAt: isoDate,
    startAt: isoDate,
    endAt: isoDate,
    requestId: id.optional(),
    note: z.string().trim().max(1000).optional(),
  })
  .strict();

/**
 * Callable `recordPaymentAndActivate` (FR-106, FR-080, AC-030): records an
 * offline payment, activates the plan with its dates, closes the request,
 * restores hidden content (FR-101) and emails the owner (§5.5 step 4).
 */
export async function recordPaymentAndActivate(
  db: Firestore,
  auth: CallerAuth | undefined | null,
  data: unknown,
): Promise<{ paymentId: string; restored: number }> {
  const admin = assertAdmin(auth);
  const input = parseInput(recordPaymentSchema, data);
  const startAt = toDate(input.startAt);
  const endAt = toDate(input.endAt);
  if (!(endAt.getTime() > startAt.getTime())) throw appError("invalid-input", "The end date must be after the start date.", { field: "endAt" });
  const plan = await planOrThrow(db, input.planId);
  if (plan.isFree === true) throw appError("invalid-input", "Pick a paid plan.", { field: "planId" });
  const features = await getPlanFeatures(async (p) => (await db.doc(p).get()).data(), input.planId);
  const root = db.doc(`restaurants/${input.restaurantId}`);

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(root);
    if (!snap.exists) throw appError("not-found", "Restaurant not found.");
    const r = snap.data() as Data;
    const requestId = input.requestId ?? (typeof r.pendingUpgradeRequestId === "string" ? r.pendingUpgradeRequestId : undefined);
    const request = requestId ? await tx.get(db.doc(`upgradeRequests/${requestId}`)) : null;
    const before = subscriptionFrom(r.subscription, r.planId);
    const after: Subscription = {
      status: "active",
      planId: input.planId,
      billing: input.billing,
      startAt,
      expiresAt: endAt,
      graceEndsAt: null,
      remindersSent: [],
    };
    const payment = root.collection("payments").doc();
    tx.create(payment, {
      amountMinor: input.amountMinor,
      currency: input.currency,
      method: input.method,
      provider: "offline",
      reference: input.reference,
      paidAt: Timestamp.fromDate(toDate(input.paidAt)),
      planId: input.planId,
      billing: input.billing,
      periodStart: Timestamp.fromDate(startAt),
      periodEnd: Timestamp.fromDate(endAt),
      requestId: requestId ?? null,
      note: input.note ?? null,
      recordedBy: admin.uid,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.update(root, {
      planId: input.planId,
      subscription: subscriptionDoc(after),
      planFeatures: restaurantPlanFeatures(features),
      pendingUpgradeRequestId: null,
    });
    // FRD §13 (M13): free → paid is a conversion, paid → paid a renewal.
    tx.set(db.doc("stats/platform"), before.status === "free" ? { conversions: FieldValue.increment(1) } : { renewals: FieldValue.increment(1) }, { merge: true });
    if (request?.exists) {
      tx.update(request.ref, { status: "activated", resolvedAt: FieldValue.serverTimestamp(), resolvedBy: admin.uid, paymentId: payment.id });
    }
    tx.create(root.collection("subscriptionHistory").doc(), {
      action: "activate",
      fromPlanId: r.planId ?? "free",
      toPlanId: input.planId,
      fromStatus: before.status,
      toStatus: "active",
      startAt: Timestamp.fromDate(startAt),
      expiresAt: Timestamp.fromDate(endAt),
      paymentId: payment.id,
      reason: input.note ?? null,
      by: admin.uid,
      at: FieldValue.serverTimestamp(),
    });
    await writeAudit(
      {
        actorUid: admin.uid,
        actorRole: "platformAdmin",
        action: "subscription.activate",
        restaurantId: input.restaurantId,
        target: `restaurants/${input.restaurantId}/payments/${payment.id}`,
        ...(input.note ? { reason: input.note } : {}),
        details: {
          planId: input.planId,
          billing: input.billing,
          amountMinor: input.amountMinor,
          currency: input.currency,
          method: input.method,
          reference: input.reference,
          startAt: startAt.toISOString(),
          endAt: endAt.toISOString(),
          requestId: requestId ?? null,
        },
      },
      { db: db as never, transaction: tx },
    );
    await queueOwnerMail(db, r.ownerEmail, "activated", { restaurantId: input.restaurantId, name: String(r.name ?? ""), planName: String(plan.name ?? "Pro"), date: endAt }, tx);
    return { paymentId: payment.id };
  });
  const restored = await clearHiddenOverLimit(db, input.restaurantId, { uid: admin.uid, role: "platformAdmin" }, { notify: false });
  return { ...result, restored };
}

// ---- admin: changeSubscription ----------------------------------------------

export const changeSubscriptionSchema = z.discriminatedUnion("action", [
  z.object({ action: z.literal("extend"), restaurantId: id, expiresAt: isoDate, reason: z.string().trim().min(3).max(1000) }).strict(),
  z
    .object({
      action: z.literal("modify"),
      restaurantId: id,
      planId: planIdSchema,
      startAt: isoDate.optional(),
      expiresAt: isoDate.optional(),
      reason: z.string().trim().min(3).max(1000),
    })
    .strict(),
  z.object({ action: z.literal("downgrade"), restaurantId: id, reason: z.string().trim().min(3).max(1000) }).strict(),
]);

/**
 * Callable `changeSubscription` (FR-081): extend the expiry, modify the
 * plan or dates, or downgrade to Free, always with a reason in the audit
 * log. Lower limits run `applyPlanLimits`; higher ones restore hidden content.
 */
export async function changeSubscription(
  db: Firestore,
  auth: CallerAuth | undefined | null,
  data: unknown,
  deps: { now?: () => Date } = {},
): Promise<{ subscription: Data }> {
  const admin = assertAdmin(auth);
  const input = parseInput(changeSubscriptionSchema, data);
  const now = (deps.now ?? (() => new Date()))();
  const root = db.doc(`restaurants/${input.restaurantId}`);
  const snap = await root.get();
  if (!snap.exists) throw appError("not-found", "Restaurant not found.");
  const r = snap.data() as Data;
  const before = subscriptionFrom(r.subscription, r.planId);
  let after: Subscription;
  let planId = String(r.planId ?? "free");

  if (input.action === "extend") {
    if (!isPaid(before)) throw appError("invalid-input", "Only a paid plan can be extended.", { field: "action" });
    const expiresAt = toDate(input.expiresAt);
    if (expiresAt.getTime() <= now.getTime()) throw appError("invalid-input", "The new expiry must be in the future.", { field: "expiresAt" });
    after = { ...before, status: "active", expiresAt, graceEndsAt: null, remindersSent: [] };
  } else if (input.action === "downgrade") {
    after = freeSubscription(now);
    planId = "free";
  } else {
    const plan = await planOrThrow(db, input.planId);
    planId = input.planId;
    if (plan.isFree === true) {
      after = freeSubscription(now);
    } else {
      const expiresAt = input.expiresAt ? toDate(input.expiresAt) : before.expiresAt;
      if (!expiresAt || expiresAt.getTime() <= now.getTime()) throw appError("invalid-input", "A paid plan needs a future expiry.", { field: "expiresAt" });
      after = {
        status: "active",
        planId,
        billing: before.billing,
        startAt: input.startAt ? toDate(input.startAt) : before.startAt ?? now,
        expiresAt,
        graceEndsAt: null,
        remindersSent: [],
      };
    }
  }

  const oldFeatures = await getPlanFeatures(async (p) => (await db.doc(p).get()).data(), r.planId);
  const newFeatures = await getPlanFeatures(async (p) => (await db.doc(p).get()).data(), planId);
  const batch = db.batch();
  batch.update(root, { planId, subscription: subscriptionDoc(after), planFeatures: restaurantPlanFeatures(newFeatures) });
  batch.create(root.collection("subscriptionHistory").doc(), {
    action: input.action,
    fromPlanId: r.planId ?? "free",
    toPlanId: planId,
    fromStatus: before.status,
    toStatus: after.status,
    expiresAt: after.expiresAt ? Timestamp.fromDate(after.expiresAt) : null,
    reason: input.reason,
    by: admin.uid,
    at: FieldValue.serverTimestamp(),
  });
  await writeAudit(
    {
      actorUid: admin.uid,
      actorRole: "platformAdmin",
      action: `subscription.${input.action}`,
      restaurantId: input.restaurantId,
      target: `restaurants/${input.restaurantId}`,
      reason: input.reason,
      details: {
        fromPlanId: r.planId ?? "free",
        toPlanId: planId,
        fromStatus: before.status,
        toStatus: after.status,
        expiresAt: after.expiresAt?.toISOString() ?? null,
      },
    },
    { db: db as never, batch },
  );
  await batch.commit();

  const lower = (a: number | null, b: number | null) => b !== null && (a === null || b < a);
  const tighter =
    lower(oldFeatures.maxItems, newFeatures.maxItems) ||
    lower(oldFeatures.maxCategories, newFeatures.maxCategories) ||
    (oldFeatures.premiumThemes && !newFeatures.premiumThemes);
  const actor = { uid: admin.uid, role: "platformAdmin" as const };
  if (tighter) {
    await applyPlanLimits(db, input.restaurantId, actor, { reason: input.reason });
    if (input.action === "downgrade" || after.status === "free") {
      await queueOwnerMail(db, r.ownerEmail, "downgraded", { restaurantId: input.restaurantId, name: String(r.name ?? "") });
    }
  } else if (planId !== r.planId) {
    await clearHiddenOverLimit(db, input.restaurantId, actor);
  }
  return { subscription: subscriptionDoc(after) };
}

// ---- admin: requests --------------------------------------------------------

export const closeUpgradeRequestSchema = z.object({ requestId: id, reason: z.string().trim().min(3).max(1000) }).strict();

/** Callable `closeUpgradeRequest`: declines an open request, with a reason (audit-logged). */
export async function closeUpgradeRequest(db: Firestore, auth: CallerAuth | undefined | null, data: unknown): Promise<{ ok: true }> {
  const admin = assertAdmin(auth);
  const input = parseInput(closeUpgradeRequestSchema, data);
  const ref = db.doc(`upgradeRequests/${input.requestId}`);
  await db.runTransaction(async (tx) => {
    const req = await tx.get(ref);
    if (!req.exists) throw appError("not-found", "Request not found.");
    if (req.get("status") !== "pending") throw appError("invalid-input", "The request is already closed.");
    const rid = String(req.get("restaurantId"));
    const root = db.doc(`restaurants/${rid}`);
    const r = await tx.get(root);
    tx.update(ref, { status: "closed", reason: input.reason, resolvedAt: FieldValue.serverTimestamp(), resolvedBy: admin.uid });
    if (r.exists && r.get("pendingUpgradeRequestId") === input.requestId) tx.update(root, { pendingUpgradeRequestId: null });
    await writeAudit(
      { actorUid: admin.uid, actorRole: "platformAdmin", action: "subscription.closeRequest", restaurantId: rid, target: `upgradeRequests/${input.requestId}`, reason: input.reason },
      { db: db as never, transaction: tx },
    );
  });
  return { ok: true };
}

export const listUpgradeRequestsSchema = z.object({ status: z.enum(["pending", "activated", "closed"]).default("pending"), limit: z.number().int().min(1).max(200).default(100) }).strict();

/**
 * Callable `adminListUpgradeRequests`: the admin queue. Admin screens read
 * through callables (master plan, M01: the rules always require TOTP).
 */
export async function adminListUpgradeRequests(db: Firestore, auth: CallerAuth | undefined | null, data: unknown): Promise<{ requests: Data[] }> {
  assertAdmin(auth);
  const input = parseInput(listUpgradeRequestsSchema, data ?? {});
  const snap = await db.collection("upgradeRequests").where("status", "==", input.status).get();
  const iso = (v: unknown) => (v instanceof Timestamp ? v.toDate().toISOString() : null);
  const requests = snap.docs
    .map((d) => {
      const x = d.data();
      return {
        id: d.id,
        restaurantId: x.restaurantId,
        restaurantName: x.restaurantName ?? "",
        ownerEmail: x.ownerEmail ?? null,
        ownerMobile: x.ownerMobile ?? null,
        country: x.country ?? null,
        currency: x.currency ?? null,
        currentPlanId: x.currentPlanId ?? "free",
        requestedPlanId: x.requestedPlanId,
        billing: x.billing,
        status: x.status,
        createdAt: iso(x.createdAt),
        resolvedAt: iso(x.resolvedAt),
      };
    })
    .sort((a, b) => String(a.createdAt).localeCompare(String(b.createdAt)))
    .slice(0, input.limit);
  return { requests };
}

// ---- owner: hidden content (swap, downgrade by choice) -----------------------

export const setHiddenSchema = z
  .object({
    restaurantId: id,
    hideItemIds: z.array(id).max(500).default([]),
    showItemIds: z.array(id).max(500).default([]),
    hideCategoryIds: z.array(id).max(500).default([]),
    showCategoryIds: z.array(id).max(500).default([]),
    /** Downgrade to Free now, with these choices (FR-101 "the owner picks"). */
    downgrade: z.boolean().default(false),
  })
  .strict();

/**
 * Callable `setHiddenOverLimit` (FR-101).
 *
 * - Swap (`downgrade: false`): change which items and categories are
 *   hidden; the visible ones must fit the current plan. A draft change:
 *   the owner publishes.
 * - Downgrade by choice (`downgrade: true`, paid plans only): the visible
 *   ones must fit Free; then the plan switches to Free and
 *   `applyPlanLimits` publishes.
 */
export async function setHiddenOverLimit(
  db: Firestore,
  auth: CallerAuth | undefined | null,
  data: unknown,
  deps: { now?: () => Date } = {},
): Promise<{ visibleItems: number; visibleCategories: number; published: number | null }> {
  assertSignedIn(auth); // before input checks: anonymous callers learn nothing (M13)
  const input = parseInput(setHiddenSchema, data);
  const owner = await assertOwner(auth, input.restaurantId, { db });
  const r = owner.restaurant;
  const sub = subscriptionFrom(r.subscription, r.planId);
  if (input.downgrade && !isPaid(sub)) throw appError("already-on-plan", "Already on the Free plan.");
  const targetPlan = input.downgrade ? "free" : String(r.planId ?? "free");
  const limits = await getPlanFeatures(async (p) => (await db.doc(p).get()).data(), targetPlan);

  const root = db.doc(`restaurants/${input.restaurantId}`);
  const [cats, items] = await Promise.all([root.collection("categories").get(), root.collection("items").get()]);
  const live = <T extends { data(): Data }>(d: T) => d.data().deletedAt === null || d.data().deletedAt === undefined;
  const hidden = (set: Set<string>, show: string[], hide: string[], docs: Array<{ id: string; data(): Data }>) => {
    const ids = new Set(docs.filter(live).map((d) => d.id));
    for (const x of [...show, ...hide]) if (!ids.has(x)) throw appError("not-found", "Unknown or deleted entry.", { id: x });
    for (const d of docs) if (live(d) && d.data().hiddenOverLimit === true) set.add(d.id);
    for (const x of show) set.delete(x);
    for (const x of hide) set.add(x);
    return docs.filter((d) => live(d) && !set.has(d.id)).length;
  };
  const hiddenItems = new Set<string>();
  const hiddenCats = new Set<string>();
  const visibleItems = hidden(hiddenItems, input.showItemIds, input.hideItemIds, items.docs);
  const visibleCategories = hidden(hiddenCats, input.showCategoryIds, input.hideCategoryIds, cats.docs);
  if (limits.maxItems !== null && visibleItems > limits.maxItems) {
    throw appError("limit-reached", "Too many visible items for the plan.", { limit: "items", max: limits.maxItems, count: visibleItems, planId: targetPlan });
  }
  if (limits.maxCategories !== null && visibleCategories > limits.maxCategories) {
    throw appError("limit-reached", "Too many visible categories for the plan.", { limit: "categories", max: limits.maxCategories, count: visibleCategories, planId: targetPlan });
  }

  const now = FieldValue.serverTimestamp();
  const batch = db.batch();
  // A swap is the owner's own draft change (updatedAt bumps the publish bar).
  const touch = input.downgrade ? {} : { updatedAt: now };
  for (const d of items.docs) {
    if (!live(d)) continue;
    const want = hiddenItems.has(d.id);
    if ((d.data().hiddenOverLimit === true) !== want) batch.update(d.ref, { hiddenOverLimit: want, ...touch });
  }
  for (const d of cats.docs) {
    if (!live(d)) continue;
    const want = hiddenCats.has(d.id);
    if ((d.data().hiddenOverLimit === true) !== want) batch.update(d.ref, { hiddenOverLimit: want, ...touch });
  }
  if (input.downgrade) {
    const free = freeSubscription((deps.now ?? (() => new Date()))());
    batch.update(root, { planId: "free", subscription: subscriptionDoc(free), pendingUpgradeRequestId: null });
    batch.create(root.collection("subscriptionHistory").doc(), {
      action: "ownerDowngrade",
      fromPlanId: r.planId ?? "free",
      toPlanId: "free",
      fromStatus: sub.status,
      toStatus: "free",
      reason: null,
      by: owner.uid,
      at: now,
    });
  } else {
    batch.update(root, { draftUpdatedAt: now });
  }
  await writeAudit(
    {
      actorUid: owner.uid,
      actorRole: "owner",
      action: input.downgrade ? "subscription.ownerDowngrade" : "menu.swapHidden",
      restaurantId: input.restaurantId,
      target: `restaurants/${input.restaurantId}`,
      details: { visibleItems, visibleCategories, hiddenItems: hiddenItems.size, hiddenCategories: hiddenCats.size },
    },
    { db: db as never, batch },
  );
  await batch.commit();
  let published: number | null = null;
  if (input.downgrade) {
    published = (await applyPlanLimits(db, input.restaurantId, { uid: owner.uid, role: "owner" }, { notify: false })).published;
  }
  return { visibleItems, visibleCategories, published };
}
