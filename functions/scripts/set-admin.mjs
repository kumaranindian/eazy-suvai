// Bootstraps a platform administrator (M01; M11 adds the setAdminRole
// callable for later changes).
//
// Emulators (creates the user if missing, email already verified):
//   FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 FIRESTORE_EMULATOR_HOST=localhost:8080 \
//     node scripts/set-admin.mjs --project demo-eazysuvai --email admin@example.com --password 'Secret123!'
//
// Real project (uses Application Default Credentials: `gcloud auth application-default login`).
// The user must already exist and have verified their email (TOTP enrolment needs it):
//   node scripts/set-admin.mjs --project eazy-suvai-dev --email you@avail404.com
//
// The admin then signs in to the admin app and enrols an authenticator app (FR-084).
import { parseArgs } from "node:util";

import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";

const { values } = parseArgs({
  options: {
    project: { type: "string" },
    email: { type: "string" },
    password: { type: "string" },
    revoke: { type: "boolean", default: false },
  },
});
if (!values.project || !values.email) {
  console.error("Usage: node scripts/set-admin.mjs --project <id> --email <email> [--password <pw>] [--revoke]");
  process.exit(2);
}
const emulator = Boolean(process.env.FIREBASE_AUTH_EMULATOR_HOST);
if (!emulator && values.project.startsWith("demo-")) {
  console.error("demo- projects only exist on the emulators. Set FIREBASE_AUTH_EMULATOR_HOST.");
  process.exit(2);
}

initializeApp({ projectId: values.project });
const auth = getAuth();
const db = getFirestore();

let user;
try {
  user = await auth.getUserByEmail(values.email);
} catch (e) {
  if (!emulator || e.code !== "auth/user-not-found") throw e;
  user = await auth.createUser({
    email: values.email,
    password: values.password ?? "Admin12345!",
    emailVerified: true,
  });
}
if ((user.customClaims ?? {}).role === "owner") {
  console.error("This account owns a restaurant. Use a separate account for administration.");
  process.exit(1);
}

const role = values.revoke ? null : "platformAdmin";
await auth.setCustomUserClaims(user.uid, role ? { role } : {});
const expire = new Date();
expire.setUTCFullYear(expire.getUTCFullYear() + 2);
const batch = db.batch();
const userRef = db.doc(`users/${user.uid}`);
if (role) {
  batch.set(userRef, { email: user.email, displayName: user.displayName ?? null, role, createdAt: FieldValue.serverTimestamp() }, { merge: true });
} else {
  batch.delete(userRef);
}
batch.create(db.collection("auditLogs").doc(), {
  actorUid: "bootstrap-script",
  actorRole: "system",
  action: role ? "admin.grant" : "admin.revoke",
  target: `users/${user.uid}`,
  details: { email: user.email },
  at: FieldValue.serverTimestamp(),
  expireAt: Timestamp.fromDate(expire),
});
await batch.commit();
await auth.revokeRefreshTokens(user.uid);
console.log(`${role ? "Granted" : "Revoked"} platformAdmin for ${user.email} (${user.uid}).`);
