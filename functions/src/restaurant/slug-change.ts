import { FieldValue, type Firestore } from "firebase-admin/firestore";
import { z } from "zod";

import { writeAudit, type AuditDb } from "../lib/audit";
import { assertOwner, type CallerAuth , assertSignedIn } from "../lib/auth";
import { appError } from "../lib/errors";
import { parseInput } from "../lib/validation";
import { reservedSlugs } from "../auth/register";
import { isValidSlug, SLUG_MAX } from "../auth/slug";

export const changeSlugSchema = z
  .object({
    restaurantId: z.string().min(1).max(128),
    /** Trimmed and lower-cased before the FR-092 checks. */
    slug: z
      .string()
      .max(SLUG_MAX * 2)
      .transform((s) => s.trim().toLowerCase()),
    /** Only check availability; change nothing. */
    dryRun: z.boolean().optional(),
  })
  .strict();

export interface ChangeSlugResult {
  slug: string;
  /** The slug before the change (equal to [slug] when nothing changed). */
  previousSlug: string;
  /** False for a dry run, or when [slug] already was the current slug. */
  changed: boolean;
  /** Dry run: the slug may be taken by this restaurant. */
  available: boolean;
}

/**
 * FR-092 format and reserved-word checks, with a precise error code.
 *
 * @param slug Normalized candidate.
 * @param reserved Reserved words.
 */
export function assertSlugAllowed(slug: string, reserved: readonly string[]): void {
  if (!isValidSlug(slug, [])) {
    throw appError("slug-invalid", "Slug does not match the FR-092 format.");
  }
  if (reserved.includes(slug)) {
    throw appError("slug-reserved", "Slug is a reserved word.");
  }
}

/**
 * Changes a restaurant's public menu slug (FR-093, BR-002), or with
 * `dryRun` only checks that it could.
 *
 * In one transaction:
 * - `slugs/{new}` must not exist, or must be one of this restaurant's own
 *   old slugs (an owner may go back to an earlier link);
 * - `slugs/{old}` becomes `{current: false, replacedAt}` and is kept for
 *   the life of the account, so M07 can answer the old URL with a 301;
 * - `slugs/{new}` becomes `{restaurantId, current: true}`;
 * - `restaurants/{rid}.slug` is set;
 * - an `auditLogs` entry `restaurant.changeSlug` records both slugs.
 *
 * The slug is not draft content: the new link works at once, without a
 * publish. The QR code never changes (BR-006).
 *
 * @param db Firestore.
 * @param auth The caller.
 * @param data The raw callable data.
 * @return The resulting slug.
 */
export async function changeSlug(
  db: Firestore,
  auth: CallerAuth | undefined | null,
  data: unknown,
): Promise<ChangeSlugResult> {
  assertSignedIn(auth); // before input checks: anonymous callers learn nothing (M13)
  const input = parseInput(changeSlugSchema, data);
  const { uid, restaurantId } = await assertOwner(auth, input.restaurantId, { db });
  const reserved = await reservedSlugs(db);
  const slug = input.slug;
  assertSlugAllowed(slug, reserved);

  const restaurantRef = db.doc(`restaurants/${restaurantId}`);
  const newRef = db.doc(`slugs/${slug}`);

  return db.runTransaction(async (tx) => {
    const [restaurant, existing] = await tx.getAll(restaurantRef, newRef);
    const current = restaurant.get("slug") as string;

    if (existing.exists && existing.get("restaurantId") !== restaurantId) {
      throw appError("slug-taken", "Slug is used by another restaurant.");
    }
    if (current === slug) {
      return { slug, previousSlug: current, changed: false, available: true };
    }
    if (input.dryRun) {
      return { slug, previousSlug: current, changed: false, available: true };
    }

    const now = FieldValue.serverTimestamp();
    if (current) {
      tx.set(db.doc(`slugs/${current}`), { current: false, replacedAt: now }, { merge: true });
    }
    if (existing.exists) {
      // Taking back one of this restaurant's old slugs.
      tx.update(newRef, { current: true, replacedAt: FieldValue.delete(), reclaimedAt: now });
    } else {
      tx.create(newRef, { restaurantId, current: true, createdAt: now });
    }
    tx.update(restaurantRef, { slug });
    await writeAudit(
      {
        actorUid: uid,
        actorRole: "owner",
        action: "restaurant.changeSlug",
        restaurantId,
        target: `restaurants/${restaurantId}`,
        details: { from: current ?? null, to: slug, reclaimed: existing.exists },
      },
      { db: db as unknown as AuditDb, transaction: tx },
    );
    return { slug, previousSlug: current, changed: true, available: true };
  });
}
