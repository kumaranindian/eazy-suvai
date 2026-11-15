/**
 * `subscriptionDaily` (M10, FR-100): once a day, for every paid
 * subscription, applies {@link dailyActionFor} at "now":
 * - reminders 14, 7 and 1 days before expiry (email + `remindersSent`);
 * - at expiry: `grace` until expiry + `config/platform.graceDays` (default
 *   14, 0–30), with an email;
 * - at the end of grace: Free, `subscriptionHistory`, audit, email, then
 *   `applyPlanLimits` (FR-101). The public menu and QR code stay live.
 *
 * Idempotent: each step checks the stored status inside a transaction, so
 * a retried or doubled run does nothing twice.
 */
import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";

import { writeAudit } from "../lib/audit";
import { getPlanFeatures, restaurantPlanFeatures } from "../lib/plan-limits";
import { applyPlanLimits } from "./apply-limits";
import { subscriptionDoc } from "./callables";
import { queueOwnerMail } from "./mail";
import { dailyActionFor, freeSubscription, graceDaysFrom, subscriptionFrom, type DailyAction } from "./model";

export interface DailyReport {
  checked: number;
  reminders: number;
  graced: number;
  downgraded: number;
  errors: number;
}

const SYSTEM = { uid: "system", role: "system" as const };

/**
 * Runs the daily job.
 *
 * @param db Firestore.
 * @param now The time to evaluate at (a fixed date in tests).
 * @return Counts of what happened.
 */
export async function runSubscriptionDaily(db: Firestore, now: Date, log: (msg: string, e: unknown) => void = () => undefined): Promise<DailyReport> {
  const graceDays = graceDaysFrom((await db.doc("config/platform").get()).get("graceDays"));
  const snap = await db.collection("restaurants").where("subscription.status", "in", ["active", "grace"]).get();
  const report: DailyReport = { checked: snap.size, reminders: 0, graced: 0, downgraded: 0, errors: 0 };
  for (const doc of snap.docs) {
    try {
      const kind = await step(db, doc.id, now, graceDays);
      if (kind === "remind") report.reminders++;
      if (kind === "enterGrace") report.graced++;
      if (kind === "downgrade") report.downgraded++;
    } catch (e) {
      report.errors++;
      log(`subscriptionDaily ${doc.id}`, e);
    }
  }
  return report;
}

async function step(db: Firestore, rid: string, now: Date, graceDays: number): Promise<DailyAction["kind"]> {
  const root = db.doc(`restaurants/${rid}`);
  const action = await db.runTransaction(async (tx) => {
    const snap = await tx.get(root);
    const r = snap.data() ?? {};
    const sub = subscriptionFrom(r.subscription, r.planId);
    const a = dailyActionFor(sub, now, graceDays);
    const name = String(r.name ?? "");
    if (a.kind === "remind") {
      tx.update(root, { "subscription.remindersSent": FieldValue.arrayUnion(...a.markSent) });
      await queueOwnerMail(db, r.ownerEmail, "reminder", { restaurantId: rid, name, days: a.daysLeft, date: sub.expiresAt ?? undefined, planName: "Pro" }, tx);
    } else if (a.kind === "enterGrace") {
      tx.update(root, { "subscription.status": "grace", "subscription.graceEndsAt": Timestamp.fromDate(a.graceEndsAt) });
      tx.create(root.collection("subscriptionHistory").doc(), {
        action: "grace", fromPlanId: sub.planId, toPlanId: sub.planId, fromStatus: "active", toStatus: "grace",
        expiresAt: sub.expiresAt ? Timestamp.fromDate(sub.expiresAt) : null, reason: null, by: "system", at: FieldValue.serverTimestamp(),
      });
      await writeAudit({ actorUid: "system", actorRole: "system", action: "subscription.grace", restaurantId: rid, target: `restaurants/${rid}`, details: { graceEndsAt: a.graceEndsAt.toISOString() } }, { db: db as never, transaction: tx });
      await queueOwnerMail(db, r.ownerEmail, "grace", { restaurantId: rid, name, date: a.graceEndsAt }, tx);
    } else if (a.kind === "downgrade") {
      tx.update(root, { planId: "free", subscription: subscriptionDoc(freeSubscription(now)) });
      tx.create(root.collection("subscriptionHistory").doc(), {
        action: "expire", fromPlanId: sub.planId, toPlanId: "free", fromStatus: sub.status, toStatus: "free",
        expiresAt: null, reason: null, by: "system", at: FieldValue.serverTimestamp(),
      });
      await writeAudit({ actorUid: "system", actorRole: "system", action: "subscription.expire", restaurantId: rid, target: `restaurants/${rid}`, details: { fromPlanId: sub.planId } }, { db: db as never, transaction: tx });
      await queueOwnerMail(db, r.ownerEmail, "downgraded", { restaurantId: rid, name }, tx);
    }
    return a.kind;
  });
  if (action === "downgrade") {
    await applyPlanLimits(db, rid, SYSTEM, { reason: "Paid plan expired after grace (FR-100)" });
  }
  return action;
}

/** Keeps `planFeatures` in step for a restaurant (used after manual data fixes and by M11). */
export async function syncPlanFeatures(db: Firestore, rid: string): Promise<void> {
  const root = db.doc(`restaurants/${rid}`);
  const r = (await root.get()).data() ?? {};
  const f = await getPlanFeatures(async (p) => (await db.doc(p).get()).data(), r.planId);
  await root.update({ planFeatures: restaurantPlanFeatures(f) });
}
