/**
 * Admin callables for restaurants (M11, FR-086 to FR-089, FR-099, BR-014).
 *
 * - `adminSearchRestaurants`: name prefix (`nameLower`), slug, email or
 *   mobile; filters status, plan, country and registration date; cursor
 *   pages ordered by registration date (newest first).
 * - `adminGetRestaurant`: profile summary, subscription, payments,
 *   subscription history and activity (publishes, plan changes, status
 *   changes from the audit log; sign-ins from Firebase Auth metadata).
 * - `setRestaurantStatus`: valid transitions only, a required reason, the
 *   owner's refresh tokens revoked on suspend and deactivate, the status
 *   mirrored to `users/{ownerUid}.accountStatus` (the owner app's notice),
 *   and an audit entry.
 *
 * Admins never edit menus here (§3.5).
 */
import type { Auth } from "firebase-admin/auth";
import { FieldValue, Timestamp, type Firestore, type Query } from "firebase-admin/firestore";
import { z } from "zod";

import { writeAudit } from "../lib/audit";
import { assertAdmin, type CallerAuth } from "../lib/auth";
import { appError } from "../lib/errors";
import { parseInput } from "../lib/validation";

type Data = Record<string, unknown>;

const id = z.string().min(1).max(128).regex(/^[A-Za-z0-9_-]+$/);
const iso = (v: unknown) => (v instanceof Timestamp ? v.toDate().toISOString() : null);

// ---- status (FR-088, FR-099) -------------------------------------------------

export type RestaurantStatus = "active" | "suspended" | "deactivated";

/** Days a deactivated account can be reactivated (FR-099). */
export const REACTIVATE_DAYS = 90;

/** FR-088 transitions; `deleted` is M12's (account deletion), never set here. */
const TRANSITIONS: Record<string, RestaurantStatus[]> = {
  active: ["suspended", "deactivated"],
  suspended: ["active", "deactivated"],
  deactivated: ["active"],
};

/** Whether `from → to` is allowed at `now` (pure). */
export function canTransition(from: string, to: RestaurantStatus, deactivatedAt: Date | null, now: Date): boolean {
  if (!(TRANSITIONS[from] ?? []).includes(to)) return false;
  if (from === "deactivated" && to === "active") {
    return deactivatedAt !== null && now.getTime() - deactivatedAt.getTime() <= REACTIVATE_DAYS * 86_400_000;
  }
  return true;
}

/** Audit action of a transition. */
export function statusAction(from: string, to: RestaurantStatus): string {
  if (to === "suspended") return "restaurant.suspend";
  if (to === "deactivated") return "restaurant.deactivate";
  return from === "deactivated" ? "restaurant.reactivate" : "restaurant.activate";
}

export const setStatusSchema = z
  .object({ restaurantId: id, status: z.enum(["active", "suspended", "deactivated"]), reason: z.string().trim().min(3).max(1000) })
  .strict();

export interface AdminDeps {
  auth?: Pick<Auth, "revokeRefreshTokens" | "getUser">;
  now?: () => Date;
}

/** Callable `setRestaurantStatus` (FR-088, AC-016). */
export async function setRestaurantStatus(
  db: Firestore,
  caller: CallerAuth | undefined | null,
  data: unknown,
  deps: AdminDeps = {},
): Promise<{ status: RestaurantStatus; previous: string }> {
  const admin = assertAdmin(caller);
  const input = parseInput(setStatusSchema, data);
  const now = (deps.now ?? (() => new Date()))();
  const root = db.doc(`restaurants/${input.restaurantId}`);
  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(root);
    if (!snap.exists) throw appError("not-found", "Restaurant not found.");
    const r = snap.data() as Data;
    const from = String(r.status ?? "active");
    const deactivatedAt = r.deactivatedAt instanceof Timestamp ? r.deactivatedAt.toDate() : null;
    if (!canTransition(from, input.status, deactivatedAt, now)) {
      throw appError("invalid-input", `Cannot change status from ${from} to ${input.status}.`, { from, to: input.status });
    }
    const patch: Data = {
      status: input.status,
      statusReason: input.reason,
      statusChangedAt: Timestamp.fromDate(now),
      statusChangedBy: admin.uid,
    };
    if (input.status === "deactivated") patch.deactivatedAt = Timestamp.fromDate(now);
    if (input.status === "active") patch.deactivatedAt = FieldValue.delete();
    tx.update(root, patch);
    if (typeof r.ownerUid === "string" && r.ownerUid !== "") {
      tx.set(db.doc(`users/${r.ownerUid}`), { accountStatus: input.status, accountStatusAt: Timestamp.fromDate(now) }, { merge: true });
    }
    await writeAudit(
      {
        actorUid: admin.uid,
        actorRole: "platformAdmin",
        action: statusAction(from, input.status),
        restaurantId: input.restaurantId,
        target: `restaurants/${input.restaurantId}`,
        reason: input.reason,
        details: { from, to: input.status },
      },
      { db: db as never, transaction: tx },
    );
    return { from, ownerUid: typeof r.ownerUid === "string" ? r.ownerUid : null };
  });
  // Sign the owner out everywhere (FR-099: blocked). ID tokens expire within the hour.
  if (result.ownerUid && input.status !== "active" && deps.auth) {
    try {
      await deps.auth.revokeRefreshTokens(result.ownerUid);
    } catch (e) {
      if ((e as { code?: string }).code !== "auth/user-not-found") throw e;
    }
  }
  return { status: input.status, previous: result.from };
}

// ---- search (FR-086) ----------------------------------------------------------

export const searchSchema = z
  .object({
    query: z.string().trim().max(120).optional(),
    status: z.enum(["active", "suspended", "deactivated", "deleted"]).optional(),
    planId: z.string().regex(/^[A-Za-z0-9_-]{1,64}$/).optional(),
    country: z.string().regex(/^[A-Z]{2}$/).optional(),
    createdFrom: z.string().date().optional(),
    createdTo: z.string().date().optional(),
    pageSize: z.number().int().min(1).max(100).default(25),
    /** The last row's id from the previous page. */
    cursor: id.optional(),
  })
  .strict();

export type SearchInput = z.infer<typeof searchSchema>;

/** How a search text is matched (pure). */
export function queryKind(q: string): { kind: "email"; value: string } | { kind: "mobile"; value: string } | { kind: "text"; value: string } {
  const t = q.trim();
  if (t.includes("@")) return { kind: "email", value: t.toLowerCase() };
  const digits = t.replace(/[\s()-]/g, "");
  if (/^\+?\d{6,15}$/.test(digits)) return { kind: "mobile", value: digits.startsWith("+") ? digits : `+${digits}` };
  return { kind: "text", value: t.toLowerCase() };
}

function row(id: string, d: Data): Data {
  const sub = (d.subscription ?? {}) as Data;
  const counts = (d.counts ?? {}) as Data;
  return {
    id,
    name: d.name ?? "",
    slug: d.slug ?? "",
    ownerEmail: d.ownerEmail ?? null,
    ownerMobile: d.ownerMobile ?? null,
    country: d.country ?? null,
    status: d.status ?? "active",
    planId: d.planId ?? "free",
    subscriptionStatus: sub.status ?? "free",
    expiresAt: iso(sub.expiresAt),
    items: typeof counts.items === "number" ? counts.items : 0,
    publishedVersion: typeof d.publishedVersion === "number" ? d.publishedVersion : null,
    createdAt: iso(d.createdAt),
  };
}

/** Callable `adminSearchRestaurants` (FR-086). */
export async function adminSearchRestaurants(
  db: Firestore,
  caller: CallerAuth | undefined | null,
  data: unknown,
): Promise<{ rows: Data[]; nextCursor: string | null }> {
  assertAdmin(caller);
  const input = parseInput(searchSchema, data ?? {});
  const col = db.collection("restaurants");
  const from = input.createdFrom ? Timestamp.fromDate(new Date(`${input.createdFrom}T00:00:00Z`)) : null;
  const to = input.createdTo ? Timestamp.fromDate(new Date(`${input.createdTo}T23:59:59.999Z`)) : null;
  const matchesFilters = (d: Data) =>
    (!input.status || d.status === input.status) &&
    (!input.planId || (d.planId ?? "free") === input.planId) &&
    (!input.country || d.country === input.country) &&
    (!from || (d.createdAt instanceof Timestamp && d.createdAt.toMillis() >= from.toMillis())) &&
    (!to || (d.createdAt instanceof Timestamp && d.createdAt.toMillis() <= to.toMillis()));

  const q = input.query ? queryKind(input.query) : null;
  // Exact lookups (email, mobile, slug) return few rows: filter in memory.
  if (q && q.kind !== "text") {
    const field = q.kind === "email" ? "ownerEmail" : "ownerMobile";
    const snap = await col.where(field, "==", q.value).limit(50).get();
    return { rows: snap.docs.filter((d) => matchesFilters(d.data())).map((d) => row(d.id, d.data())), nextCursor: null };
  }

  let query: Query;
  if (q) {
    // Name prefix (nameLower, M03) ordered by name; a slug is checked too.
    query = col.orderBy("nameLower").startAt(q.value).endAt(`${q.value}`);
  } else {
    query = col;
    if (input.status) query = query.where("status", "==", input.status);
    if (input.planId) query = query.where("planId", "==", input.planId);
    if (input.country) query = query.where("country", "==", input.country);
    if (from) query = query.where("createdAt", ">=", from);
    if (to) query = query.where("createdAt", "<=", to);
    query = query.orderBy("createdAt", "desc");
  }
  if (input.cursor) {
    const after = await col.doc(input.cursor).get();
    if (after.exists) query = query.startAfter(after);
  }
  const snap = await query.limit(input.pageSize + 1).get();
  let docs = snap.docs;
  if (q) {
    docs = docs.filter((d) => matchesFilters(d.data()));
    if (!input.cursor) {
      const slug = await db.doc(`slugs/${q.value}`).get();
      const rid = slug.get("restaurantId");
      if (typeof rid === "string" && !docs.some((d) => d.id === rid)) {
        const r = await col.doc(rid).get();
        if (r.exists && matchesFilters(r.data() as Data)) docs = [r as never, ...docs];
      }
    }
  }
  const page = docs.slice(0, input.pageSize);
  return {
    rows: page.map((d) => row(d.id, d.data() as Data)),
    nextCursor: snap.docs.length > input.pageSize ? snap.docs[input.pageSize - 1].id : null,
  };
}

// ---- detail (FR-087, FR-089) --------------------------------------------------

export const getRestaurantSchema = z.object({ restaurantId: id }).strict();

const ACTIVITY_ACTIONS = /^(menu\.(publish|rollback|discardDraft|publishPlanLimits)|subscription\.|restaurant\.)/;

/** Callable `adminGetRestaurant`. */
export async function adminGetRestaurant(
  db: Firestore,
  caller: CallerAuth | undefined | null,
  data: unknown,
  deps: AdminDeps = {},
): Promise<Data> {
  assertAdmin(caller);
  const input = parseInput(getRestaurantSchema, data);
  const root = db.doc(`restaurants/${input.restaurantId}`);
  const snap = await root.get();
  if (!snap.exists) throw appError("not-found", "Restaurant not found.");
  const r = snap.data() as Data;
  const [payments, history, audit] = await Promise.all([
    root.collection("payments").orderBy("paidAt", "desc").limit(50).get(),
    root.collection("subscriptionHistory").orderBy("at", "desc").limit(50).get(),
    db.collection("auditLogs").where("restaurantId", "==", input.restaurantId).orderBy("at", "desc").limit(100).get(),
  ]);
  let signIns: Data = {};
  if (deps.auth && typeof r.ownerUid === "string") {
    try {
      const u = await deps.auth.getUser(r.ownerUid);
      signIns = { createdAt: u.metadata.creationTime ?? null, lastSignInAt: u.metadata.lastSignInTime ?? null, lastActiveAt: u.metadata.lastRefreshTime ?? null, disabled: u.disabled };
    } catch {
      signIns = {};
    }
  }
  const sub = (r.subscription ?? {}) as Data;
  const contact = (r.contact ?? {}) as Data;
  return {
    restaurant: {
      ...row(snap.id, r),
      ownerName: r.ownerName ?? "",
      businessType: r.businessType ?? null,
      city: contact.city ?? null,
      currency: r.currency ?? null,
      timezone: r.timezone ?? null,
      qrCode: r.qrCode ?? null,
      statusReason: r.statusReason ?? null,
      statusChangedAt: iso(r.statusChangedAt),
      deactivatedAt: iso(r.deactivatedAt),
      publishedAt: iso(r.publishedAt),
      categories: ((r.counts ?? {}) as Data).categories ?? 0,
      pendingUpgradeRequestId: r.pendingUpgradeRequestId ?? null,
    },
    subscription: {
      status: sub.status ?? "free",
      planId: sub.planId ?? r.planId ?? "free",
      billing: sub.billing ?? null,
      startAt: iso(sub.startAt),
      expiresAt: iso(sub.expiresAt),
      graceEndsAt: iso(sub.graceEndsAt),
    },
    payments: payments.docs.map((d) => {
      const p = d.data();
      return { id: d.id, amountMinor: p.amountMinor, currency: p.currency, method: p.method, provider: p.provider, reference: p.reference, planId: p.planId, paidAt: iso(p.paidAt), periodStart: iso(p.periodStart), periodEnd: iso(p.periodEnd), recordedBy: p.recordedBy };
    }),
    history: history.docs.map((d) => {
      const h = d.data();
      return { id: d.id, action: h.action, fromPlanId: h.fromPlanId, toPlanId: h.toPlanId, fromStatus: h.fromStatus, toStatus: h.toStatus, reason: h.reason ?? null, by: h.by, at: iso(h.at) };
    }),
    activity: audit.docs
      .map((d) => ({ id: d.id, ...(d.data() as Data) }) as Data & { id: string })
      .filter((a) => ACTIVITY_ACTIONS.test(String(a.action)))
      .map((a) => ({ id: a.id, action: a.action, actorRole: a.actorRole, actorUid: a.actorUid, reason: a.reason ?? null, details: a.details ?? {}, at: iso(a.at) })),
    signIns,
  };
}
