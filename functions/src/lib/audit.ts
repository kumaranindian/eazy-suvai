import {
  FieldValue,
  getFirestore,
  Timestamp,
  type DocumentReference,
  type Transaction,
  type WriteBatch,
} from "firebase-admin/firestore";
import { z } from "zod";

/** How long audit logs are kept (FRD §7.7). A Firestore TTL policy on
 * `auditLogs.expireAt` deletes them afterwards. */
export const AUDIT_RETENTION_YEARS = 2;

export const auditEntrySchema = z.object({
  actorUid: z.string().min(1),
  actorRole: z.enum(["owner", "platformAdmin", "system"]),
  /** Dotted verb, for example `restaurant.suspend` or `plan.update`. */
  action: z.string().regex(/^[a-z][a-zA-Z]*(\.[a-z][a-zA-Z]*)+$/),
  restaurantId: z.string().min(1).optional(),
  /** Path of the thing acted on, for example `restaurants/abc`. */
  target: z.string().min(1),
  reason: z.string().max(1000).optional(),
  details: z.record(z.string(), z.unknown()).optional(),
});

export type AuditEntry = z.infer<typeof auditEntrySchema>;

/** Minimal Firestore surface used here, so tests can pass a fake. */
export interface AuditDb {
  collection(path: string): {
    doc(): { id: string; set(data: Record<string, unknown>): Promise<unknown> };
  };
}

export interface WriteAuditOptions {
  db?: AuditDb;
  /** Write inside this transaction (preferred: audit commits with the change). */
  transaction?: Transaction;
  /** Or add to this batch. */
  batch?: WriteBatch;
  /** Clock override for tests. */
  now?: Date;
}

/**
 * Builds the stored audit document.
 *
 * @param entry The audit entry.
 * @param now The current time.
 * @return The Firestore data, without undefined fields.
 */
export function buildAuditDoc(entry: AuditEntry, now: Date): Record<string, unknown> {
  const parsed = auditEntrySchema.parse(entry);
  const expire = new Date(now.getTime());
  expire.setUTCFullYear(expire.getUTCFullYear() + AUDIT_RETENTION_YEARS);
  const doc: Record<string, unknown> = {
    actorUid: parsed.actorUid,
    actorRole: parsed.actorRole,
    action: parsed.action,
    target: parsed.target,
    details: parsed.details ?? {},
    at: FieldValue.serverTimestamp(),
    expireAt: Timestamp.fromDate(expire),
  };
  if (parsed.restaurantId !== undefined) doc.restaurantId = parsed.restaurantId;
  if (parsed.reason !== undefined) doc.reason = parsed.reason;
  return doc;
}

/**
 * Writes an `auditLogs` entry for a sensitive action (BR-014).
 *
 * Pass `transaction` or `batch` so the log commits atomically with the change
 * it records.
 *
 * @param entry What happened, who did it, and to what.
 * @param options Firestore, transaction or batch, and clock overrides.
 * @return The new audit log id.
 */
export async function writeAudit(
  entry: AuditEntry,
  options: WriteAuditOptions = {},
): Promise<string> {
  const data = buildAuditDoc(entry, options.now ?? new Date());
  const db = options.db ?? (getFirestore() as unknown as AuditDb);
  const ref = db.collection("auditLogs").doc();
  if (options.transaction) {
    options.transaction.create(ref as unknown as DocumentReference, data);
  } else if (options.batch) {
    options.batch.create(ref as unknown as DocumentReference, data);
  } else {
    await ref.set(data);
  }
  return ref.id;
}
