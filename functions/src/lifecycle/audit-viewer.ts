/**
 * `adminListAuditLogs` (M12, FR-090, BR-014): the audit log for the admin
 * app, newest first, filtered by actor, action, restaurant and date range,
 * with cursor pages. Equality filters use the composite indexes
 * `(actorUid|action|restaurantId, at desc)`.
 */
import { Timestamp, type Firestore, type Query } from "firebase-admin/firestore";
import { z } from "zod";

import { assertAdmin, type CallerAuth } from "../lib/auth";
import { parseInput } from "../lib/validation";

export const auditListSchema = z
  .object({
    actorUid: z.string().trim().min(1).max(128).optional(),
    action: z.string().trim().regex(/^[a-z][a-zA-Z.]{1,80}$/).optional(),
    restaurantId: z.string().trim().regex(/^[A-Za-z0-9_-]{1,128}$/).optional(),
    from: z.string().date().optional(),
    to: z.string().date().optional(),
    pageSize: z.number().int().min(1).max(200).default(50),
    cursor: z.string().regex(/^[A-Za-z0-9_-]{1,128}$/).optional(),
  })
  .strict();

const iso = (v: unknown) => (v instanceof Timestamp ? v.toDate().toISOString() : null);

export async function adminListAuditLogs(
  db: Firestore,
  caller: CallerAuth | undefined | null,
  data: unknown,
): Promise<{ entries: Record<string, unknown>[]; nextCursor: string | null }> {
  assertAdmin(caller);
  const input = parseInput(auditListSchema, data ?? {});
  const col = db.collection("auditLogs");
  let q: Query = col;
  if (input.actorUid) q = q.where("actorUid", "==", input.actorUid);
  if (input.action) q = q.where("action", "==", input.action);
  if (input.restaurantId) q = q.where("restaurantId", "==", input.restaurantId);
  if (input.from) q = q.where("at", ">=", Timestamp.fromDate(new Date(`${input.from}T00:00:00Z`)));
  if (input.to) q = q.where("at", "<=", Timestamp.fromDate(new Date(`${input.to}T23:59:59.999Z`)));
  q = q.orderBy("at", "desc");
  if (input.cursor) {
    const after = await col.doc(input.cursor).get();
    if (after.exists) q = q.startAfter(after);
  }
  const snap = await q.limit(input.pageSize + 1).get();
  const docs = snap.docs.slice(0, input.pageSize);
  return {
    entries: docs.map((d) => {
      const x = d.data();
      return {
        id: d.id,
        at: iso(x.at),
        actorUid: x.actorUid ?? null,
        actorRole: x.actorRole ?? null,
        action: x.action ?? null,
        restaurantId: x.restaurantId ?? null,
        target: x.target ?? null,
        reason: x.reason ?? null,
        details: x.details ?? {},
        anonymized: x.anonymizedAt !== undefined && x.anonymizedAt !== null,
      };
    }),
    nextCursor: snap.docs.length > input.pageSize ? docs[docs.length - 1].id : null,
  };
}
