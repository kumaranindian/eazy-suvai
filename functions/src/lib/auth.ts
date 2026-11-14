import { getFirestore } from "firebase-admin/firestore";

import { appError } from "./errors";

/** User roles set as custom claims by Functions (architecture §5). */
export type Role = "owner" | "platformAdmin";

/** The `auth` part of a callable request. */
export interface CallerAuth {
  uid: string;
  token: {
    email_verified?: boolean;
    role?: unknown;
    restaurantId?: unknown;
    [claim: string]: unknown;
  };
}

/** Minimal Firestore reader, so tests can pass a fake. */
export interface DocReader {
  doc(path: string): {
    get(): Promise<{ exists: boolean; data(): Record<string, unknown> | undefined }>;
  };
}

export type RestaurantStatus = "active" | "suspended" | "deactivated" | "deleted";

export interface OwnerContext {
  uid: string;
  restaurantId: string;
  restaurant: Record<string, unknown>;
}

export interface AssertOwnerOptions {
  /** Firestore to read from. Defaults to the Admin SDK instance. */
  db?: DocReader;
  /**
   * Restaurant statuses allowed. Defaults to `["active"]`. Account lifecycle
   * actions (export, deletion request; M12) may also allow `deactivated`.
   */
  allowedStatuses?: readonly RestaurantStatus[];
}

/**
 * Checks that the caller is signed in.
 *
 * @param auth The callable request's `auth`.
 * @return The caller's auth, narrowed to non-null.
 */
export function assertSignedIn(auth: CallerAuth | undefined | null): CallerAuth {
  if (!auth?.uid) {
    throw appError("unauthenticated", "Sign-in required.");
  }
  return auth;
}

/**
 * Checks that the caller is a platform administrator.
 *
 * MFA for admins (FR-084): the ID token must come from a sign-in that
 * completed a TOTP second factor (`firebase.sign_in_second_factor`). The Auth
 * emulator has no TOTP, so the check is skipped only on the functions
 * emulator under a `demo-` project (see {@link isDemoEmulator}).
 *
 * @param auth The callable request's `auth`.
 * @param options `requireMfa` overrides the default (tests).
 * @return The admin's uid.
 */
export function assertAdmin(
  auth: CallerAuth | undefined | null,
  options: { requireMfa?: boolean } = {},
): { uid: string } {
  const caller = assertSignedIn(auth);
  if (caller.token.role !== "platformAdmin") {
    throw appError("permission-denied", "Platform administrator role required.");
  }
  const requireMfa = options.requireMfa ?? !isDemoEmulator();
  if (requireMfa && secondFactorOf(caller) !== "totp") {
    throw appError("mfa-required", "Sign in with your authenticator code.");
  }
  return { uid: caller.uid };
}

/** The second factor used at sign-in, from the `firebase` token claim. */
export function secondFactorOf(auth: CallerAuth): string | undefined {
  const firebase = auth.token.firebase as { sign_in_second_factor?: unknown } | undefined;
  const factor = firebase?.sign_in_second_factor;
  return typeof factor === "string" ? factor : undefined;
}

/** True only inside the Functions emulator running a `demo-` project, which
 * can never reach a real Firebase project. */
export function isDemoEmulator(env: NodeJS.ProcessEnv = process.env): boolean {
  const project = env.GCLOUD_PROJECT ?? env.GOOGLE_CLOUD_PROJECT ?? "";
  return env.FUNCTIONS_EMULATOR === "true" && project.startsWith("demo-");
}

/**
 * Checks that the caller owns `restaurantId` and that the restaurant may be
 * changed (BR-011, AC-017). Mirrors `isOwner()` in firestore.rules:
 *
 * 1. signed in;
 * 2. email verified (FR-091);
 * 3. role claim `owner` and `restaurantId` claim equal to `restaurantId`;
 * 4. `restaurants/{restaurantId}` exists, its `ownerUid` is the caller, and
 *    its `status` is allowed (default: `active`).
 *
 * @param auth The callable request's `auth`.
 * @param restaurantId The restaurant the caller wants to act on.
 * @param options Firestore override and allowed statuses.
 * @return The caller's uid and the restaurant document data.
 */
export async function assertOwner(
  auth: CallerAuth | undefined | null,
  restaurantId: string,
  options: AssertOwnerOptions = {},
): Promise<OwnerContext> {
  const caller = assertSignedIn(auth);
  if (caller.token.email_verified !== true) {
    throw appError("email-not-verified", "Email address is not verified.");
  }
  if (typeof restaurantId !== "string" || restaurantId.length === 0) {
    throw appError("invalid-input", "restaurantId is required.");
  }
  if (caller.token.role !== "owner" || caller.token.restaurantId !== restaurantId) {
    throw appError("permission-denied", "Caller does not own this restaurant.");
  }

  const db: DocReader = options.db ?? getFirestore();
  const snap = await db.doc(`restaurants/${restaurantId}`).get();
  const restaurant = snap.exists ? snap.data() : undefined;
  if (!restaurant) {
    throw appError("not-found", "Restaurant not found.");
  }
  if (restaurant.ownerUid !== caller.uid) {
    throw appError("permission-denied", "Caller does not own this restaurant.");
  }
  const allowed = options.allowedStatuses ?? ["active"];
  if (!allowed.includes(restaurant.status as RestaurantStatus)) {
    throw appError("account-inactive", "Restaurant is not active.", {
      status: restaurant.status,
    });
  }
  return { uid: caller.uid, restaurantId, restaurant };
}
