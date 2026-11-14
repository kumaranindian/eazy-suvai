import type { Auth, UserRecord } from "firebase-admin/auth";
import type { Firestore } from "firebase-admin/firestore";

import { writeAudit, type AuditDb } from "../lib/audit";

/** FR-091: registrations left unverified this long are deleted. */
export const UNVERIFIED_TTL_DAYS = 7;

export interface CleanupDeps {
  db: Firestore;
  auth: Auth;
  now?: Date;
}

/** True if [user] is an unverified, non-admin account older than the TTL. */
export function isExpiredUnverified(user: UserRecord, now: Date): boolean {
  if (user.emailVerified) return false;
  if (user.customClaims?.role === "platformAdmin") return false;
  const created = Date.parse(user.metadata.creationTime);
  if (Number.isNaN(created)) return false;
  return now.getTime() - created >= UNVERIFIED_TTL_DAYS * 24 * 60 * 60 * 1000;
}

/**
 * Deletes accounts left unverified for 7 days (FR-091), with their
 * `users` doc, restaurant (and any subcollections), slugs and QR code. This
 * releases the email address and the slug. Writes one audit entry per
 * account.
 *
 * Unverified owners never reached the dashboard, so their QR code was never
 * downloaded; deleting it does not break a printed code (BR-006).
 *
 * @param deps Firestore, Auth and clock.
 * @return The uids deleted.
 */
export async function cleanupUnverifiedUsers(deps: CleanupDeps): Promise<string[]> {
  const now = deps.now ?? new Date();
  const expired: UserRecord[] = [];
  let pageToken: string | undefined;
  do {
    const page = await deps.auth.listUsers(1000, pageToken);
    expired.push(...page.users.filter((u) => isExpiredUnverified(u, now)));
    pageToken = page.pageToken;
  } while (pageToken);

  const deleted: string[] = [];
  for (const user of expired) {
    await deleteUnverifiedAccount(deps, user);
    deleted.push(user.uid);
  }
  return deleted;
}

async function deleteUnverifiedAccount(deps: CleanupDeps, user: UserRecord): Promise<void> {
  const { db, auth } = deps;
  const userRef = db.doc(`users/${user.uid}`);
  const userDoc = await userRef.get();
  const rid = (userDoc.get("restaurantId") ?? user.customClaims?.restaurantId) as string | undefined;

  const batch = db.batch();
  const details: Record<string, unknown> = { email: user.email ?? null };
  if (typeof rid === "string" && rid) {
    const restaurantRef = db.doc(`restaurants/${rid}`);
    const restaurant = await restaurantRef.get();
    if (restaurant.exists && restaurant.get("ownerUid") === user.uid) {
      const [slugs, codes] = await Promise.all([
        db.collection("slugs").where("restaurantId", "==", rid).get(),
        db.collection("qrCodes").where("restaurantId", "==", rid).get(),
      ]);
      slugs.docs.forEach((d) => batch.delete(d.ref));
      codes.docs.forEach((d) => batch.delete(d.ref));
      details.restaurantId = rid;
      details.slugs = slugs.docs.map((d) => d.id);
      details.qrCodes = codes.docs.map((d) => d.id);
      // Subcollections first (normally none for an account that never logged in).
      for (const sub of await restaurantRef.listCollections()) {
        await db.recursiveDelete(sub);
      }
      batch.delete(restaurantRef);
    }
  }
  batch.delete(userRef);
  await writeAudit(
    {
      actorUid: "system",
      actorRole: "system",
      action: "account.purgeUnverified",
      ...(details.restaurantId ? { restaurantId: rid } : {}),
      target: `users/${user.uid}`,
      details,
    },
    { db: db as unknown as AuditDb, batch },
  );
  await batch.commit();
  await auth.deleteUser(user.uid);
}
