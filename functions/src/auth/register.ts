import type { Auth } from "firebase-admin/auth";
import { FieldValue, type DocumentReference, type Firestore } from "firebase-admin/firestore";
import { isValidPhoneNumber, parsePhoneNumberWithError, type CountryCode } from "libphonenumber-js";
import { z } from "zod";

import { writeAudit, type AuditDb } from "../lib/audit";
import { appError } from "../lib/errors";
import { DEFAULT_PLAN_FEATURES, restaurantPlanFeatures } from "../lib/plan-limits";
import { parseInput } from "../lib/validation";
import { BUSINESS_TYPES, COUNTRIES, COUNTRY_CODES } from "./countries";
import { generateQrCode } from "./qr-code";
import { DEFAULT_RESERVED_SLUGS, FALLBACK_SLUG_BASE, slugCandidates, slugify, SLUG_MAX } from "./slug";

/** Plan every new restaurant starts on (FR-079). M10 creates `plans/free`. */
export const FREE_PLAN_ID = "free";

const SLUG_BATCH = 10;
const SLUG_BATCHES = 5;
const QR_ATTEMPTS = 5;

const text = (max: number) =>
  z
    .string()
    .transform((s) => s.trim().replace(/\s+/g, " "))
    .pipe(z.string().min(1).max(max));

export const registrationSchema = z
  .object({
    restaurantName: text(100),
    ownerName: text(100),
    /** As typed, or E.164. Checked against [country] (FR-003). */
    mobile: z.string().trim().min(4).max(32),
    country: z.enum(COUNTRY_CODES),
    businessType: z.enum(BUSINESS_TYPES),
    /** Optional. Used for the slug suffix on collision (FR-092). */
    city: text(60).optional(),
  })
  .strict()
  .transform((input, ctx) => {
    const country = input.country as CountryCode;
    if (!isValidPhoneNumber(input.mobile, country)) {
      ctx.addIssue({ code: "custom", path: ["mobile"], message: "Invalid mobile number for country." });
      return z.NEVER;
    }
    const phone = parsePhoneNumberWithError(input.mobile, country);
    if (phone.country !== undefined && phone.country !== country) {
      ctx.addIssue({ code: "custom", path: ["mobile"], message: "Mobile number is from another country." });
      return z.NEVER;
    }
    return { ...input, mobile: phone.number as string };
  });

export type RegistrationInput = z.input<typeof registrationSchema>;

export interface RegistrationResult {
  restaurantId: string;
  slug: string;
  qrCode: string;
  /** False when the account was already registered (idempotent retry). */
  created: boolean;
}

export interface RegisterDeps {
  db: Firestore;
  auth: Auth;
  /** Random source for QR codes (tests). */
  random?: (max: number) => number;
}

export interface RegisterCaller {
  uid: string;
  token: Record<string, unknown>;
}

/** Thrown inside the transaction when the user doc appeared meanwhile. */
class AlreadyRegistered extends Error {}

/**
 * Creates the owner's tenant (M01, FR-001/002/004/007/008/047, BR-017).
 *
 * In one Firestore transaction: `users/{uid}`, `restaurants/{rid}` on the
 * Free plan, `slugs/{slug}`, `qrCodes/{code}` and an audit entry. Then sets
 * the custom claims `{role: 'owner', restaurantId}`.
 *
 * Idempotent: if the caller already has a `users` doc, the claims are
 * re-applied and the existing restaurant is returned, so a retry after a
 * failed claim update is safe and a second call never creates a second
 * restaurant. Called with no input, it only resumes; if there is nothing to
 * resume it fails with `registration-incomplete`.
 *
 * The verification email is sent by the client right after this returns
 * (`User.sendEmailVerification`); the Admin SDK cannot send email.
 *
 * @param deps Firestore and Auth.
 * @param caller The signed-in caller (may be unverified).
 * @param data The raw callable data.
 * @return The restaurant id, slug and QR code.
 */
export async function registerOwner(
  deps: RegisterDeps,
  caller: RegisterCaller | undefined | null,
  data: unknown,
): Promise<RegistrationResult> {
  if (!caller?.uid) throw appError("unauthenticated", "Sign-in required.");
  const { db, auth } = deps;
  const { uid, token } = caller;

  if (token.role !== undefined && token.role !== "owner") {
    throw appError("permission-denied", "This account cannot own a restaurant.");
  }

  const existing = await resumeExisting(deps, uid);
  if (existing) return existing;

  if (data === undefined || data === null || (typeof data === "object" && Object.keys(data).length === 0)) {
    throw appError("registration-incomplete", "No restaurant yet. Send the registration details.");
  }
  const input = parseInput(registrationSchema, data);

  const email = typeof token.email === "string" ? token.email.toLowerCase() : undefined;
  const provider = (token.firebase as { sign_in_provider?: string } | undefined)?.sign_in_provider;
  if (!email || provider !== "password") {
    throw appError("permission-denied", "Register with an email address and password.");
  }

  const reserved = await reservedSlugs(db);
  const defaults = COUNTRIES[input.country];
  const restaurantRef = db.collection("restaurants").doc();
  const rid = restaurantRef.id;

  let result: RegistrationResult;
  try {
    result = await db.runTransaction(async (tx) => {
      const userRef = db.doc(`users/${uid}`);
      if ((await tx.get(userRef)).exists) throw new AlreadyRegistered();

      const slug = await pickSlug((refs) => tx.getAll(...refs), db, input.restaurantName, input.city, reserved);
      const qrCode = await pickQrCode((ref) => tx.get(ref), db, deps.random);

      const now = FieldValue.serverTimestamp();
      tx.create(userRef, {
        email,
        displayName: input.ownerName,
        mobile: input.mobile,
        role: "owner",
        restaurantId: rid,
        createdAt: now,
      });
      tx.create(restaurantRef, {
        name: input.restaurantName,
        nameLower: input.restaurantName.toLowerCase(),
        ownerUid: uid,
        ownerName: input.ownerName,
        ownerEmail: email,
        ownerMobile: input.mobile,
        businessType: input.businessType,
        country: input.country,
        currency: defaults.currency,
        timezone: defaults.timezone,
        contact: input.city ? { city: input.city } : {},
        slug,
        qrCode,
        status: "active",
        planId: FREE_PLAN_ID,
        subscription: { status: "free", planId: FREE_PLAN_ID, billing: null, startAt: now, expiresAt: null, graceEndsAt: null, remindersSent: [] },
        // M10: the plan flags the rules and the owner app read.
        planFeatures: restaurantPlanFeatures(DEFAULT_PLAN_FEATURES.free),
        counts: { categories: 0, items: 0 },
        publishedVersion: null,
        pricesNeedReview: false,
        themeId: null,
        draftUpdatedAt: now,
        createdAt: now,
      });
      tx.create(db.doc(`slugs/${slug}`), { restaurantId: rid, current: true, createdAt: now });
      tx.create(db.doc(`qrCodes/${qrCode}`), { restaurantId: rid, kind: "restaurant", createdAt: now });
      await writeAudit(
        {
          actorUid: uid,
          actorRole: "owner",
          action: "restaurant.register",
          restaurantId: rid,
          target: `restaurants/${rid}`,
          details: { slug, qrCode, planId: FREE_PLAN_ID, country: input.country },
        },
        { db: db as unknown as AuditDb, transaction: tx },
      );
      return { restaurantId: rid, slug, qrCode, created: true };
    });
  } catch (e) {
    if (e instanceof AlreadyRegistered) {
      const resumed = await resumeExisting(deps, uid);
      if (resumed) return resumed;
    }
    throw e;
  }

  await setOwnerClaims(auth, uid, result.restaurantId);
  return result;
}

/** If `users/{uid}` exists, re-applies the claims and returns its restaurant. */
async function resumeExisting(deps: RegisterDeps, uid: string): Promise<RegistrationResult | undefined> {
  const user = await deps.db.doc(`users/${uid}`).get();
  if (!user.exists) return undefined;
  const rid = user.get("restaurantId");
  if (user.get("role") !== "owner" || typeof rid !== "string") {
    throw appError("permission-denied", "This account cannot own a restaurant.");
  }
  const restaurant = await deps.db.doc(`restaurants/${rid}`).get();
  if (!restaurant.exists || restaurant.get("ownerUid") !== uid) {
    throw appError("not-found", "Restaurant not found.");
  }
  await setOwnerClaims(deps.auth, uid, rid);
  return { restaurantId: rid, slug: restaurant.get("slug"), qrCode: restaurant.get("qrCode"), created: false };
}

/** Sets `{role: 'owner', restaurantId}`, keeping any other claims. */
async function setOwnerClaims(auth: Auth, uid: string, restaurantId: string): Promise<void> {
  const user = await auth.getUser(uid);
  const claims = user.customClaims ?? {};
  if (claims.role === "owner" && claims.restaurantId === restaurantId) return;
  await auth.setCustomUserClaims(uid, { ...claims, role: "owner", restaurantId });
}

/** Reserved words from `config/platform.reservedSlugs`, else the FR-092 list. */
export async function reservedSlugs(db: Firestore): Promise<string[]> {
  const snap = await db.doc("config/platform").get();
  const list = snap.exists ? snap.get("reservedSlugs") : undefined;
  if (Array.isArray(list) && list.every((s) => typeof s === "string")) {
    return list.map((s: string) => s.toLowerCase());
  }
  return [...DEFAULT_RESERVED_SLUGS];
}

type GetAll = (refs: DocumentReference[]) => Promise<{ exists: boolean }[]>;
type GetOne = (ref: DocumentReference) => Promise<{ exists: boolean }>;

/**
 * First free slug in FR-092 order. Any existing `slugs` doc blocks a slug,
 * including old (`current: false`) and released ones (FR-093).
 */
export async function pickSlug(
  getAll: GetAll,
  db: Firestore,
  name: string,
  city: string | undefined,
  reserved: readonly string[],
): Promise<string> {
  let next = 2;
  for (let batch = 0; batch < SLUG_BATCHES; batch++) {
    const candidates =
      batch === 0
        ? slugCandidates(name, city, reserved, SLUG_BATCH)
        : slugCandidates(name, city, reserved, SLUG_BATCH, next);
    const snaps = await getAll(candidates.map((s) => db.doc(`slugs/${s}`)));
    const free = candidates.find((_, i) => !snaps[i].exists);
    if (free) return free;
    const last = candidates[candidates.length - 1].match(/-(\d+)$/);
    next = last ? Number(last[1]) + 1 : next + SLUG_BATCH;
  }
  // Extremely common name: fall back to a random suffix.
  const base = slugify(name, SLUG_MAX - 9) || FALLBACK_SLUG_BASE;
  for (let i = 0; i < QR_ATTEMPTS; i++) {
    const slug = `${base}-${generateQrCode().toLowerCase()}`;
    if (!(await getAll([db.doc(`slugs/${slug}`)]))[0].exists) return slug;
  }
  throw appError("unknown", "Could not reserve a slug.");
}

/** A QR code that has never been used (BR-006). */
async function pickQrCode(
  get: GetOne,
  db: Firestore,
  random?: (max: number) => number,
): Promise<string> {
  for (let i = 0; i < QR_ATTEMPTS; i++) {
    const code = generateQrCode(random);
    if (!(await get(db.doc(`qrCodes/${code}`))).exists) return code;
  }
  throw appError("unknown", "Could not reserve a QR code.");
}
