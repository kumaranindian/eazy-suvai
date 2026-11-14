// Helpers for *.emu.test.ts. Run with `npm run test:emulators`, which starts
// the Auth, Firestore and Functions emulators for project demo-eazysuvai.
import { getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

export const PROJECT_ID = "demo-eazysuvai";
export const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? "127.0.0.1:9099";
export const FIRESTORE_HOST = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8080";
export const FUNCTIONS_HOST = "127.0.0.1:5001";

if (!process.env.FIREBASE_AUTH_EMULATOR_HOST || !process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error("Emulator tests must run under `npm run test:emulators`.");
}

/** Default bucket of the demo project (the Storage emulator's default). */
export const BUCKET = `${PROJECT_ID}.appspot.com`;

export function admin() {
  if (getApps().length === 0) initializeApp({ projectId: PROJECT_ID, storageBucket: BUCKET });
  return { db: getFirestore(), auth: getAuth() };
}

export async function resetEmulators(): Promise<void> {
  await Promise.all([
    fetch(`http://${FIRESTORE_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`, {
      method: "DELETE",
    }),
    fetch(`http://${AUTH_HOST}/emulator/v1/projects/${PROJECT_ID}/accounts`, { method: "DELETE" }),
  ]);
}

const STORAGE_HOST = process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? "127.0.0.1:9199";
const storageObjectUrl = (name: string) =>
  `http://${STORAGE_HOST}/storage/v1/b/${BUCKET}/o/${encodeURIComponent(name)}`;

/**
 * Uploads to the Storage emulator through the GCS JSON API. The
 * `@google-cloud/storage` streams fail under Jest's module sandbox, so the
 * emulator tests use plain `fetch`.
 */
export async function storageUpload(
  name: string,
  data: Buffer,
  contentType: string,
  metadata: Record<string, string>,
): Promise<void> {
  const boundary = "eazysuvai-test-boundary";
  const head = Buffer.from(
    `--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n` +
      JSON.stringify({ name, contentType, metadata }) +
      `\r\n--${boundary}\r\nContent-Type: ${contentType}\r\n\r\n`,
  );
  const body = Buffer.concat([head, data, Buffer.from(`\r\n--${boundary}--\r\n`)]);
  const res = await fetch(
    `http://${STORAGE_HOST}/upload/storage/v1/b/${BUCKET}/o?uploadType=multipart&name=${encodeURIComponent(name)}`,
    {
      method: "POST",
      headers: { "content-type": `multipart/related; boundary=${boundary}`, authorization: "Bearer owner" },
      body,
    },
  );
  if (!res.ok) throw new Error(`upload ${name}: ${res.status} ${await res.text()}`);
}

/** Downloads an object from the Storage emulator, or returns null if missing. */
export async function storageDownload(name: string): Promise<Buffer | null> {
  const res = await fetch(`${storageObjectUrl(name)}?alt=media`, { headers: { authorization: "Bearer owner" } });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`download ${name}: ${res.status}`);
  return Buffer.from(await res.arrayBuffer());
}

/** Calls the Auth emulator's Identity Toolkit REST API. */
export async function identityToolkit(
  method: string,
  body: Record<string, unknown>,
): Promise<{ status: number; json: Record<string, unknown> }> {
  const res = await fetch(`http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:${method}?key=demo`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  return { status: res.status, json: (await res.json()) as Record<string, unknown> };
}

/** Decodes a JWT payload without verifying it (emulator tokens are unsigned). */
export function claimsOf(idToken: string): Record<string, unknown> {
  return JSON.parse(Buffer.from(idToken.split(".")[1], "base64url").toString("utf8"));
}

/** Token claims as a callable request would see them. */
export function passwordCaller(uid: string, email: string) {
  return { uid, token: { email, email_verified: false, firebase: { sign_in_provider: "password" } } };
}

export const validInput = {
  restaurantName: "Spice Garden",
  ownerName: "Priya Raman",
  mobile: "9876543210",
  country: "IN",
  businessType: "restaurant",
  city: "Chennai",
};
