import { HttpsError, type FunctionsErrorCode } from "firebase-functions/v2/https";

/**
 * Stable error codes shared with the apps.
 *
 * Keep in sync with `AppErrorCode` in
 * `packages/core/lib/src/errors/app_error.dart`. The apps read
 * `error.details.code` and show a localized message for it.
 */
export const AppErrorCode = {
  unauthenticated: "unauthenticated",
  emailNotVerified: "email-not-verified",
  permissionDenied: "permission-denied",
  accountInactive: "account-inactive",
  invalidInput: "invalid-input",
  limitReached: "limit-reached",
  notFound: "not-found",
  alreadyExists: "already-exists",
  /** Signed in, but the restaurant was never created (M01). */
  registrationIncomplete: "registration-incomplete",
  /** Admin signed in without a second factor (FR-084). */
  mfaRequired: "mfa-required",
  /** Slug breaks the FR-092 format (M03). */
  slugInvalid: "slug-invalid",
  /** Slug is a reserved word (FR-092, M03). */
  slugReserved: "slug-reserved",
  /** Slug is used, now or before, by another restaurant (FR-093, M03). */
  slugTaken: "slug-taken",
  /** The item's category is deleted: pick another one (BR-004, M04). */
  categoryDeleted: "category-deleted",
  /** Publishing is blocked; `details.problems` lists why (FR-066, M06). */
  publishBlocked: "publish-blocked",
  unknown: "unknown",
} as const;

export type AppErrorCode = (typeof AppErrorCode)[keyof typeof AppErrorCode];

/** The gRPC-style HttpsError code each app code is sent with. */
const httpsCodeFor: Record<AppErrorCode, FunctionsErrorCode> = {
  "unauthenticated": "unauthenticated",
  "email-not-verified": "failed-precondition",
  "permission-denied": "permission-denied",
  "account-inactive": "failed-precondition",
  "invalid-input": "invalid-argument",
  "limit-reached": "resource-exhausted",
  "not-found": "not-found",
  "already-exists": "already-exists",
  "registration-incomplete": "failed-precondition",
  "mfa-required": "permission-denied",
  "slug-invalid": "invalid-argument",
  "slug-reserved": "invalid-argument",
  "slug-taken": "already-exists",
  "category-deleted": "failed-precondition",
  "publish-blocked": "failed-precondition",
  "unknown": "internal",
};

export interface AppErrorDetails {
  code: AppErrorCode;
  [key: string]: unknown;
}

/**
 * Creates an HttpsError carrying a stable app error code in `details.code`.
 *
 * @param code Stable app error code.
 * @param message Developer-facing message (not shown to users).
 * @param extra Extra details, for example validation issues.
 * @return The error to throw from a callable function.
 */
export function appError(
  code: AppErrorCode,
  message: string,
  extra: Record<string, unknown> = {},
): HttpsError {
  const details: AppErrorDetails = { ...extra, code };
  return new HttpsError(httpsCodeFor[code], message, details);
}

/**
 * Reads the app error code from an error thrown by `appError`.
 *
 * @param error Any thrown value.
 * @return The app code, or `undefined` if the error has none.
 */
export function appErrorCodeOf(error: unknown): AppErrorCode | undefined {
  if (!(error instanceof HttpsError)) return undefined;
  const details = error.details as Partial<AppErrorDetails> | undefined;
  return details?.code;
}
