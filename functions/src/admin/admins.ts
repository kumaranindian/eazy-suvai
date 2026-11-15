/**
 * Admin users and the dashboard (M11, FR-084, FR-085).
 *
 * The first admin is created with `scripts/set-admin.mjs`; after that,
 * `setAdminRole` grants or revokes `role: 'platformAdmin'` (same claim
 * shape, `users/{uid}`, revoked tokens, audit). An admin cannot revoke
 * themself, so the platform always keeps one.
 */
import type { Auth } from "firebase-admin/auth";
import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";
import { z } from "zod";

import { writeAudit } from "../lib/audit";
import { assertAdmin, type CallerAuth } from "../lib/auth";
import { appError } from "../lib/errors";
import { parseInput } from "../lib/validation";
import { readPlatformStats } from "./stats";

type Data = Record<string, unknown>;

export const setAdminRoleSchema = z
  .object({ email: z.string().trim().toLowerCase().email(), grant: z.boolean(), reason: z.string().trim().min(3).max(1000) })
  .strict();

export type AdminAuth = Pick<Auth, "getUserByEmail" | "setCustomUserClaims" | "revokeRefreshTokens" | "listUsers">;

/** Callable `setAdminRole` (FR-084). The user must already have an account. */
export async function setAdminRole(db: Firestore, caller: CallerAuth | undefined | null, data: unknown, deps: { auth: AdminAuth }): Promise<{ uid: string; grant: boolean }> {
  const admin = assertAdmin(caller);
  const input = parseInput(setAdminRoleSchema, data);
  let user;
  try {
    user = await deps.auth.getUserByEmail(input.email);
  } catch {
    throw appError("not-found", "No account with that email. Ask them to sign up first.", { field: "email" });
  }
  if (!input.grant && user.uid === admin.uid) throw appError("invalid-input", "You can't remove your own admin role.");
  const claims = { ...(user.customClaims ?? {}) } as Data;
  if (input.grant) {
    if (claims.role === "owner") throw appError("invalid-input", "Restaurant owner accounts can't be admins (BR-017).");
    claims.role = "platformAdmin";
  } else {
    if (claims.role !== "platformAdmin") throw appError("invalid-input", "That account is not an admin.");
    delete claims.role;
  }
  await deps.auth.setCustomUserClaims(user.uid, claims);
  await db.doc(`users/${user.uid}`).set(
    { email: input.email, role: input.grant ? "platformAdmin" : null, updatedAt: FieldValue.serverTimestamp(), ...(input.grant ? {} : { adminRevokedAt: FieldValue.serverTimestamp() }) },
    { merge: true },
  );
  await deps.auth.revokeRefreshTokens(user.uid);
  await writeAudit(
    { actorUid: admin.uid, actorRole: "platformAdmin", action: input.grant ? "admin.grant" : "admin.revoke", target: `users/${user.uid}`, reason: input.reason, details: { email: input.email } },
    { db: db as never },
  );
  return { uid: user.uid, grant: input.grant };
}

/** Callable `adminListAdmins`: platform admins from `users` (role kept in step by `setAdminRole`). */
export async function adminListAdmins(db: Firestore, caller: CallerAuth | undefined | null): Promise<{ admins: Data[] }> {
  assertAdmin(caller);
  const snap = await db.collection("users").where("role", "==", "platformAdmin").get();
  const iso = (v: unknown) => (v instanceof Timestamp ? v.toDate().toISOString() : null);
  return { admins: snap.docs.map((d) => ({ uid: d.id, email: d.get("email") ?? null, displayName: d.get("displayName") ?? null, createdAt: iso(d.get("createdAt")) })) };
}

/**
 * Callable `adminDashboard` (FR-085): `stats/platform` counters, pending
 * upgrade requests and the latest sign-ups.
 */
export async function adminDashboard(db: Firestore, caller: CallerAuth | undefined | null): Promise<Data> {
  assertAdmin(caller);
  const [stats, pending, recent] = await Promise.all([
    readPlatformStats(db),
    db.collection("upgradeRequests").where("status", "==", "pending").count().get(),
    db.collection("restaurants").orderBy("createdAt", "desc").limit(10).get(),
  ]);
  const iso = (v: unknown) => (v instanceof Timestamp ? v.toDate().toISOString() : null);
  return {
    stats,
    pendingUpgrades: pending.data().count,
    recentSignups: recent.docs.map((d) => ({
      id: d.id,
      name: d.get("name") ?? "",
      ownerEmail: d.get("ownerEmail") ?? null,
      country: d.get("country") ?? null,
      status: d.get("status") ?? "active",
      createdAt: iso(d.get("createdAt")),
    })),
  };
}
