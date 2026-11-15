/**
 * `requestAccountDeletion` (M12, FR-105): the owner closes their account.
 *
 * The restaurant is deactivated at once (FR-099: menu 410, out of the
 * sitemap), the owner is signed out everywhere, a confirmation email is
 * queued and the request is audit-logged. Within 90 days an admin can
 * reactivate it (M11); after that `purgeDaily` deletes the tenant (§7.7).
 * The owner must type the restaurant's name, so a mis-tap can't do it.
 */
import type { Auth } from "firebase-admin/auth";
import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";
import { z } from "zod";

import { writeAudit } from "../lib/audit";
import { assertOwner, type CallerAuth , assertSignedIn } from "../lib/auth";
import { appError } from "../lib/errors";
import { parseInput } from "../lib/validation";

export const deletionSchema = z
  .object({ restaurantId: z.string().min(1).max(128).regex(/^[A-Za-z0-9_-]+$/), confirmName: z.string().max(200) })
  .strict();

/** Days between the request and the purge (§7.7). */
export const DELETION_GRACE_DAYS = 90;

/** Same name, ignoring case, surrounding spaces and repeated spaces (pure). */
export function sameName(a: string, b: string): boolean {
  const norm = (s: string) => s.trim().replace(/\s+/g, " ").toLocaleLowerCase();
  return norm(a) !== "" && norm(a) === norm(b);
}

export async function requestAccountDeletion(
  db: Firestore,
  caller: CallerAuth | undefined | null,
  data: unknown,
  deps: { auth?: Pick<Auth, "revokeRefreshTokens">; now?: () => Date } = {},
): Promise<{ purgeAfter: string }> {
  assertSignedIn(caller); // before input checks: anonymous callers learn nothing (M13)
  const input = parseInput(deletionSchema, data);
  const owner = await assertOwner(caller, input.restaurantId, { db, allowedStatuses: ["active", "suspended"] });
  const name = typeof owner.restaurant.name === "string" ? owner.restaurant.name : "";
  if (!sameName(input.confirmName, name)) {
    throw appError("invalid-input", "Type your restaurant's name exactly to confirm.", { field: "confirmName" });
  }
  const now = (deps.now ?? (() => new Date()))();
  const purgeAfter = new Date(now.getTime() + DELETION_GRACE_DAYS * 86_400_000);
  const root = db.doc(`restaurants/${input.restaurantId}`);
  const batch = db.batch();
  batch.update(root, {
    status: "deactivated",
    deactivatedAt: Timestamp.fromDate(now),
    deletionRequestedAt: Timestamp.fromDate(now),
    statusReason: "Owner requested deletion (FR-105)",
    statusChangedAt: Timestamp.fromDate(now),
    statusChangedBy: owner.uid,
  });
  batch.set(db.doc(`users/${owner.uid}`), { accountStatus: "deactivated", accountStatusAt: Timestamp.fromDate(now) }, { merge: true });
  const email = owner.restaurant.ownerEmail;
  if (typeof email === "string" && email.includes("@")) {
    batch.set(db.collection("mail").doc(), {
      to: email,
      kind: "deletionRequested",
      restaurantId: input.restaurantId,
      createdAt: FieldValue.serverTimestamp(),
      message: {
        subject: "Your EazySuvai account is closed",
        text: `Hello,\n\nWe have closed the account of ${name}. The menu and QR code no longer show the menu. All data will be deleted on ${purgeAfter.toISOString().slice(0, 10)}. Until then, EazySuvai support can reopen the account if you change your mind.\n\nEazySuvai`,
      },
    });
  }
  await writeAudit(
    {
      actorUid: owner.uid,
      actorRole: "owner",
      action: "account.requestDeletion",
      restaurantId: input.restaurantId,
      target: `restaurants/${input.restaurantId}`,
      reason: "Owner requested deletion",
      details: { purgeAfter: purgeAfter.toISOString() },
    },
    { db: db as never, batch },
  );
  await batch.commit();
  if (deps.auth) await deps.auth.revokeRefreshTokens(owner.uid);
  return { purgeAfter: purgeAfter.toISOString() };
}
