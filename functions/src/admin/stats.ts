/**
 * `stats/platform` for the admin dashboard (M11, FR-085).
 *
 * `onRestaurantStats` (trigger on `restaurants/{rid}`) adds the difference
 * between a restaurant's contribution before and after each write:
 * `restaurants`, `restaurantsByStatus.{status}`,
 * `subscriptionsByStatus.{free|active|grace}`, `totalItems`, and
 * `subscriptionsExpired` (paid plans that ran out, cumulative). M09 adds
 * `menuViews` and `qrVisits`. Triggers run at least once, so
 * `recomputePlatformStats` rebuilds the counters exactly from aggregation
 * queries (an admin button, and after migrations).
 */
import { AggregateField, FieldValue, type Firestore, type Query } from "firebase-admin/firestore";

import { writeAudit } from "../lib/audit";
import { assertAdmin, type CallerAuth } from "../lib/auth";

type Data = Record<string, unknown>;

export const RESTAURANT_STATUSES = ["active", "suspended", "deactivated", "deleted"] as const;
export const SUBSCRIPTION_STATUSES = ["free", "active", "grace"] as const;

/** What one restaurant document adds to the counters (pure). */
export function contribution(d: Data | undefined): Record<string, number> {
  if (!d) return {};
  const status = typeof d.status === "string" ? d.status : "active";
  const sub = ((d.subscription ?? {}) as Data).status;
  const items = ((d.counts ?? {}) as Data).items;
  const out: Record<string, number> = { restaurants: 1, [`restaurantsByStatus.${status}`]: 1, totalItems: typeof items === "number" ? items : 0 };
  if (status !== "deleted") out[`subscriptionsByStatus.${typeof sub === "string" ? sub : "free"}`] = 1;
  // FRD §13 (M13). Activated: published at least once (kept after deletion).
  const published = typeof d.publishedVersion === "number" && d.publishedVersion >= 1;
  if (published || (d.firstPublishedAt !== null && d.firstPublishedAt !== undefined) || (status === "deleted" && d.activated === true)) out.activated = 1;
  if (status === "active" && published) out.publishedMenus = 1;
  if (typeof d.qrDownloads === "number" && d.qrDownloads > 0) out.qrDownloads = d.qrDownloads;
  return out;
}

/** Field increments for one write (pure); empty when nothing counted changed. */
export function statsDelta(before: Data | undefined, after: Data | undefined): Record<string, number> {
  const a = contribution(after);
  const b = contribution(before);
  const out: Record<string, number> = {};
  for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) {
    const v = (a[k] ?? 0) - (b[k] ?? 0);
    if (v !== 0) out[k] = v;
  }
  const was = ((before?.subscription ?? {}) as Data).status;
  const now = ((after?.subscription ?? {}) as Data).status;
  if (was === "grace" && now === "free") out.subscriptionsExpired = 1;
  return out;
}

/** Applies a delta to `stats/platform`. */
export async function applyStatsDelta(db: Firestore, delta: Record<string, number>): Promise<void> {
  if (Object.keys(delta).length === 0) return;
  const patch: Data = { updatedAt: FieldValue.serverTimestamp() };
  for (const [k, v] of Object.entries(delta)) patch[k] = FieldValue.increment(v);
  // update() reads dotted keys as field paths; create the document first if needed.
  const ref = db.doc("stats/platform");
  try {
    await ref.update(patch);
  } catch (e) {
    if ((e as { code?: unknown }).code !== 5) throw e;
    await ref.set({}, { merge: true });
    await ref.update(patch);
  }
}

/** The counters for the dashboard, with zeros for anything missing. */
export async function readPlatformStats(db: Firestore): Promise<Data> {
  const s = (await db.doc("stats/platform").get()).data() ?? {};
  const map = (v: unknown, keys: readonly string[]) => Object.fromEntries(keys.map((k) => [k, Number(((v ?? {}) as Data)[k] ?? 0)]));
  return {
    restaurants: Number(s.restaurants ?? 0),
    restaurantsByStatus: map(s.restaurantsByStatus, RESTAURANT_STATUSES),
    subscriptionsByStatus: map(s.subscriptionsByStatus, SUBSCRIPTION_STATUSES),
    subscriptionsExpired: Number(s.subscriptionsExpired ?? 0),
    totalItems: Number(s.totalItems ?? 0),
    menuViews: Number(s.menuViews ?? 0),
    qrVisits: Number(s.qrVisits ?? 0),
    // FRD §13 (M13).
    activated: Number(s.activated ?? 0),
    publishedMenus: Number(s.publishedMenus ?? 0),
    qrDownloads: Number(s.qrDownloads ?? 0),
    conversions: Number(s.conversions ?? 0),
    renewals: Number(s.renewals ?? 0),
    medianMinutesToFirstPublish: typeof s.medianMinutesToFirstPublish === "number" ? s.medianMinutesToFirstPublish : null,
    monthly: monthlyOf(s.monthly),
  };
}

/** The last 12 months of views and QR visits, newest first. */
function monthlyOf(v: unknown): { month: string; views: number; qrVisits: number }[] {
  const m = (v ?? {}) as Record<string, Data>;
  return Object.keys(m)
    .filter((k) => /^\d{4}-\d{2}$/.test(k))
    .sort()
    .reverse()
    .slice(0, 12)
    .map((k) => ({ month: k, views: Number(m[k].views ?? 0), qrVisits: Number(m[k].qrVisits ?? 0) }));
}

/** Median of sign-up → first publish, in whole minutes (pure). */
export function medianMinutes(pairs: { createdAt: Date; firstPublishedAt: Date }[]): number | null {
  const mins = pairs
    .map((p) => (p.firstPublishedAt.getTime() - p.createdAt.getTime()) / 60_000)
    .filter((m) => Number.isFinite(m) && m >= 0)
    .sort((a, b) => a - b);
  if (mins.length === 0) return null;
  const mid = Math.floor(mins.length / 2);
  return Math.round(mins.length % 2 ? mins[mid] : (mins[mid - 1] + mins[mid]) / 2);
}

/** Rebuilds the restaurant counters from aggregation queries (keeps views and expiries). */
export async function recomputeStats(db: Firestore): Promise<Data> {
  const col = db.collection("restaurants");
  const count = async (q: Query) => (await q.count().get()).data().count;
  const [total, items, byStatusCounts, bySubCounts, activated, publishedMenus, downloads, firsts] = await Promise.all([
    count(col),
    col.where("status", "!=", "deleted").aggregate({ items: AggregateField.sum("counts.items") }).get(),
    Promise.all(RESTAURANT_STATUSES.map((s) => count(col.where("status", "==", s)))),
    Promise.all(SUBSCRIPTION_STATUSES.map((s) => count(col.where("subscription.status", "==", s).where("status", "!=", "deleted")))),
    count(col.where("publishedVersion", ">=", 1)),
    count(col.where("status", "==", "active").where("publishedVersion", ">=", 1)),
    col.aggregate({ n: AggregateField.sum("qrDownloads") }).get(),
    // Two small fields per activated restaurant (10,000 at most).
    col.where("firstPublishedAt", "!=", null).select("createdAt", "firstPublishedAt").get(),
  ]);
  const asDate = (v: unknown): Date | null => (v && typeof (v as { toDate?: unknown }).toDate === "function" ? (v as { toDate(): Date }).toDate() : null);
  const median = medianMinutes(
    firsts.docs.flatMap((d) => {
      const c = asDate(d.get("createdAt"));
      const f = asDate(d.get("firstPublishedAt"));
      return c && f ? [{ createdAt: c, firstPublishedAt: f }] : [];
    }),
  );
  const byStatus = Object.fromEntries(RESTAURANT_STATUSES.map((s, i) => [s, byStatusCounts[i]]));
  const bySub = Object.fromEntries(SUBSCRIPTION_STATUSES.map((s, i) => [s, bySubCounts[i]])) as Record<string, number>;
  // Restaurants created before M10 may lack subscription.status: they are Free.
  const counted = Object.values(bySub).reduce((a, b) => a + b, 0);
  bySub.free += Math.max(0, total - byStatus.deleted - counted);
  // Deleted tombstones keep no publishedVersion: their activation stays in
  // the running counter, so the recount never lowers it.
  const prev = Number(((await db.doc("stats/platform").get()).data() ?? {}).activated ?? 0);
  const values = {
    restaurants: total,
    restaurantsByStatus: byStatus,
    subscriptionsByStatus: bySub,
    totalItems: Number(items.data().items ?? 0),
    activated: Math.max(activated, prev),
    publishedMenus,
    qrDownloads: Number(downloads.data().n ?? 0),
    medianMinutesToFirstPublish: median,
  };
  await db.doc("stats/platform").set({ ...values, recomputedAt: FieldValue.serverTimestamp() }, { merge: true });
  return values;
}

/** Callable `recomputePlatformStats` (admin). */
export async function recomputePlatformStats(db: Firestore, caller: CallerAuth | undefined | null): Promise<Data> {
  const admin = assertAdmin(caller);
  const values = await recomputeStats(db);
  await writeAudit({ actorUid: admin.uid, actorRole: "platformAdmin", action: "platform.recomputeStats", target: "stats/platform", details: values }, { db: db as never });
  return values;
}
