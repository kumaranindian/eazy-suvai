/**
 * `purgeDaily` (M12, FRD §7.7, BR-013): one function per retention rule,
 * each idempotent (it only acts on what is due at `now`) and batched.
 *
 * | Rule | Here |
 * | --- | --- |
 * | Soft-deleted categories and items: 30 days after `deletedAt` | {@link purgeSoftDeleted} |
 * | Deactivated account: 90 days after `deactivatedAt`, all tenant data and images; status `deleted` | {@link purgeTenant} via {@link purgeDeactivated} |
 * | Audit logs: personal data removed after deletion (TTL deletes after 2 years) | {@link anonymiseAudit} |
 * | Payment records: kept 8 years after deletion in `paymentArchive` | {@link purgeTenant}, {@link purgeArchivedPayments} |
 * | Slugs of deleted accounts: held 12 months, then released | {@link purgeTenant} (hold), {@link releaseSlugs} |
 * | Image folders nothing references (M02) | {@link purgeOrphanImages} |
 * | Raw analytics events (90 days), audit logs (2 years) | Firestore TTL (`firestore.indexes.json`) |
 * | Published versions: last 10 | M06, on publish |
 *
 * A purged restaurant leaves a tombstone `restaurants/{rid}` =
 * `{status: 'deleted', slug, deletedAt, purgedAt}` without personal data,
 * so its slug and QR code answer 410 (FR-099) and the stats count it.
 */
import { createHash } from "node:crypto";

import type { Auth } from "firebase-admin/auth";
import { FieldValue, Timestamp, type Firestore, type Query } from "firebase-admin/firestore";

import { writeAudit } from "../lib/audit";
import { RESTORE_DAYS } from "../menu/schemas";

type Data = Record<string, unknown>;
const DAY = 86_400_000;

export const PURGE_DEACTIVATED_DAYS = 90;
export const SLUG_HOLD_MONTHS = 12;
export const PAYMENT_RETENTION_YEARS = 8;
/** Image folders younger than this are never orphans (an upload may be mid-flight). */
export const IMAGE_MIN_AGE_DAYS = 7;

export interface PurgeDeps {
  auth?: Pick<Auth, "deleteUser">;
  /** Deletes every Storage object under a prefix. */
  deletePrefix?: (prefix: string) => Promise<void>;
  /** Lists image folders under `restaurants/{rid}/images/` with their newest upload time. */
  listImageFolders?: (rid: string) => Promise<Array<{ folder: string; updatedAt: Date }>>;
  /** Restaurants scanned for orphan images per run (round-robin). */
  imageBudget?: number;
}

export interface PurgeReport {
  softDeleted: number;
  tenants: number;
  slugsReleased: number;
  paymentsPurged: number;
  orphanFolders: number;
}

const addMonths = (d: Date, m: number) => {
  const x = new Date(d.getTime());
  x.setUTCMonth(x.getUTCMonth() + m);
  return x;
};

async function deleteQueryInChunks(db: Firestore, q: Query, limit = 400): Promise<number> {
  let n = 0;
  for (;;) {
    const snap = await q.limit(limit).get();
    if (snap.empty) return n;
    const batch = db.batch();
    for (const d of snap.docs) batch.delete(d.ref);
    await batch.commit();
    n += snap.size;
    if (snap.size < limit) return n;
  }
}

/** FR-098: categories and items deleted more than 30 days ago (collection-group queries). */
export async function purgeSoftDeleted(db: Firestore, now: Date): Promise<number> {
  const cutoff = Timestamp.fromMillis(now.getTime() - RESTORE_DAYS * DAY);
  let n = 0;
  for (const group of ["items", "categories"]) {
    n += await deleteQueryInChunks(db, db.collectionGroup(group).where("deletedAt", "<=", cutoff));
  }
  return n;
}

/** A stable pseudonym for a uid in anonymised audit entries. */
export function pseudonym(uid: string): string {
  return `anon:${createHash("sha256").update(uid).digest("hex").slice(0, 16)}`;
}

const PERSONAL_KEYS = new Set(["email", "ownerEmail", "ownerMobile", "mobile", "ownerName", "displayName", "phone"]);

/** Removes personal data from one audit entry's fields (pure). */
export function anonymisedAuditPatch(entry: Data, ownerUid: string | null): Data | null {
  const patch: Data = {};
  if (ownerUid && entry.actorUid === ownerUid) patch.actorUid = pseudonym(ownerUid);
  const details = entry.details;
  if (details && typeof details === "object") {
    const clean: Data = {};
    let changed = false;
    for (const [k, v] of Object.entries(details as Data)) {
      if (PERSONAL_KEYS.has(k)) {
        changed = true;
        continue;
      }
      clean[k] = v;
    }
    if (changed) patch.details = clean;
  }
  if (Object.keys(patch).length === 0) return null;
  patch.anonymizedAt = FieldValue.serverTimestamp();
  return patch;
}

/** BR-013/§7.7: audit entries of a deleted account keep their facts, lose personal data. */
export async function anonymiseAudit(db: Firestore, rid: string, ownerUid: string | null): Promise<number> {
  const snap = await db.collection("auditLogs").where("restaurantId", "==", rid).get();
  let n = 0;
  let batch = db.batch();
  let pending = 0;
  for (const d of snap.docs) {
    const patch = anonymisedAuditPatch(d.data(), ownerUid);
    if (!patch) continue;
    batch.update(d.ref, patch);
    n++;
    if (++pending === 400) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
  return n;
}

/**
 * Deletes one deactivated tenant (§7.7): payments to the archive, the
 * tenant subtree, Storage, the owner's account and user document, requests
 * and queued mail, slugs put on a 12-month hold, audit anonymised, and a
 * tombstone left behind. Safe to run twice.
 */
export async function purgeTenant(db: Firestore, rid: string, now: Date, deps: PurgeDeps = {}): Promise<void> {
  const root = db.doc(`restaurants/${rid}`);
  const snap = await root.get();
  const r = (snap.data() ?? {}) as Data;
  const ownerUid = typeof r.ownerUid === "string" ? r.ownerUid : null;

  // 1. Payment records are kept for 8 years (tax law), outside the tenant.
  const payments = await root.collection("payments").get();
  for (let i = 0; i < payments.docs.length; i += 400) {
    const batch = db.batch();
    for (const p of payments.docs.slice(i, i + 400)) {
      const d = p.data();
      const paidAt = d.paidAt instanceof Timestamp ? d.paidAt.toDate() : now;
      batch.set(db.doc(`paymentArchive/${rid}_${p.id}`), {
        restaurantId: rid,
        businessName: r.name ?? null,
        country: r.country ?? null,
        amountMinor: d.amountMinor ?? null,
        currency: d.currency ?? null,
        method: d.method ?? null,
        provider: d.provider ?? null,
        reference: d.reference ?? null,
        planId: d.planId ?? null,
        paidAt: d.paidAt ?? null,
        periodStart: d.periodStart ?? null,
        periodEnd: d.periodEnd ?? null,
        archivedAt: Timestamp.fromDate(now),
        retainUntil: Timestamp.fromDate(addMonths(paidAt, PAYMENT_RETENTION_YEARS * 12)),
      });
    }
    await batch.commit();
  }

  // 2. Slugs: held for 12 months after deletion (FR-093), then released.
  const slugs = await db.collection("slugs").where("restaurantId", "==", rid).get();
  const releaseAfter = Timestamp.fromDate(addMonths(now, SLUG_HOLD_MONTHS));
  if (!slugs.empty) {
    const batch = db.batch();
    for (const s of slugs.docs) {
      if (s.get("releaseAfter")) continue;
      batch.update(s.ref, { releasedAt: Timestamp.fromDate(now), releaseAfter });
    }
    await batch.commit();
  }

  // 3. Audit entries keep the facts, lose personal data (before the user goes).
  await anonymiseAudit(db, rid, ownerUid);

  // 4. Everything under the tenant, then the tombstone.
  await db.recursiveDelete(root);
  await root.set({
    status: "deleted",
      activated: typeof r.publishedVersion === "number" && r.publishedVersion >= 1,
    slug: typeof r.slug === "string" ? r.slug : null,
    qrCode: typeof r.qrCode === "string" ? r.qrCode : null,
    deletedAt: Timestamp.fromDate(now),
    purgedAt: Timestamp.fromDate(now),
    counts: { categories: 0, items: 0 },
  });

  // 5. Other personal data: requests, queued mail, the owner's account.
  await deleteQueryInChunks(db, db.collection("upgradeRequests").where("restaurantId", "==", rid));
  await deleteQueryInChunks(db, db.collection("mail").where("restaurantId", "==", rid));
  if (ownerUid) {
    await db.doc(`users/${ownerUid}`).delete();
    if (deps.auth) {
      try {
        await deps.auth.deleteUser(ownerUid);
      } catch (e) {
        if ((e as { code?: string }).code !== "auth/user-not-found") throw e;
      }
    }
  }

  // 6. Images (all renditions and originals).
  if (deps.deletePrefix) await deps.deletePrefix(`restaurants/${rid}/`);

  await writeAudit(
    {
      actorUid: "system",
      actorRole: "system",
      action: "account.purge",
      restaurantId: rid,
      target: `restaurants/${rid}`,
      details: { payments: payments.size, slugs: slugs.size, releaseAfter: releaseAfter.toDate().toISOString() },
    },
    { db: db as never },
  );
}

/** Deactivated accounts past 90 days (§7.7). */
export async function purgeDeactivated(db: Firestore, now: Date, deps: PurgeDeps = {}): Promise<number> {
  const cutoff = Timestamp.fromMillis(now.getTime() - PURGE_DEACTIVATED_DAYS * DAY);
  const due = await db.collection("restaurants").where("status", "==", "deactivated").where("deactivatedAt", "<=", cutoff).get();
  for (const d of due.docs) await purgeTenant(db, d.id, now, deps);
  return due.size;
}

/** FR-093: slugs held 12 months after a deletion become free again. */
export async function releaseSlugs(db: Firestore, now: Date): Promise<number> {
  return deleteQueryInChunks(db, db.collection("slugs").where("releaseAfter", "<=", Timestamp.fromDate(now)));
}

/** Archived payments past their 8-year retention. */
export async function purgeArchivedPayments(db: Firestore, now: Date): Promise<number> {
  return deleteQueryInChunks(db, db.collection("paymentArchive").where("retainUntil", "<=", Timestamp.fromDate(now)));
}

/** Storage folders of every image object a data object refers to (pure). */
export function referencedImageFolders(value: unknown, out = new Set<string>()): Set<string> {
  if (Array.isArray(value)) {
    for (const v of value) referencedImageFolders(v, out);
  } else if (value && typeof value === "object") {
    for (const v of Object.values(value as Data)) referencedImageFolders(v, out);
  } else if (typeof value === "string") {
    const m = /restaurants(?:\/|%2F)([A-Za-z0-9_-]+)(?:\/|%2F)images(?:\/|%2F)([A-Za-z0-9_-]+)/.exec(value);
    if (m) out.add(`restaurants/${m[1]}/images/${m[2]}/`);
  }
  return out;
}

/**
 * M02: image folders no draft document, soft-deleted document (still
 * restorable) or kept version refers to, older than 7 days. A budget of
 * restaurants per run, continuing from `config/purge.imageCursor`.
 */
export async function purgeOrphanImages(db: Firestore, now: Date, deps: PurgeDeps): Promise<number> {
  if (!deps.listImageFolders || !deps.deletePrefix) return 0;
  const budget = deps.imageBudget ?? 50;
  const cursorRef = db.doc("config/purge");
  const after = (await cursorRef.get()).get("imageCursor");
  let q = db.collection("restaurants").where("status", "in", ["active", "suspended"]).orderBy("__name__").limit(budget);
  if (typeof after === "string") q = q.startAfter(after);
  const snap = await q.get();
  let n = 0;
  for (const r of snap.docs) {
    const root = r.ref;
    const [cats, items, versions] = await Promise.all([root.collection("categories").get(), root.collection("items").get(), root.collection("versions").get()]);
    const sources = await Promise.all(versions.docs.map((v) => root.collection("versions").doc(v.id).collection("private").doc("source").get()));
    const used = new Set<string>();
    referencedImageFolders(r.data(), used);
    for (const d of [...cats.docs, ...items.docs, ...versions.docs, ...sources]) referencedImageFolders(d.data(), used);
    for (const f of await deps.listImageFolders(r.id)) {
      if (used.has(f.folder) || now.getTime() - f.updatedAt.getTime() < IMAGE_MIN_AGE_DAYS * DAY) continue;
      await deps.deletePrefix(f.folder);
      n++;
    }
  }
  await cursorRef.set({ imageCursor: snap.size < budget ? FieldValue.delete() : snap.docs[snap.size - 1].id }, { merge: true });
  return n;
}

/** Runs every rule once (the schedule calls this daily). */
export async function runPurgeDaily(db: Firestore, now: Date, deps: PurgeDeps = {}): Promise<PurgeReport> {
  const report: PurgeReport = {
    softDeleted: await purgeSoftDeleted(db, now),
    tenants: await purgeDeactivated(db, now, deps),
    slugsReleased: await releaseSlugs(db, now),
    paymentsPurged: await purgeArchivedPayments(db, now),
    orphanFolders: await purgeOrphanImages(db, now, deps),
  };
  if (Object.values(report).some((v) => v > 0)) {
    await writeAudit({ actorUid: "system", actorRole: "system", action: "platform.purge", target: "purgeDaily", details: { ...report } }, { db: db as never });
  }
  return report;
}
