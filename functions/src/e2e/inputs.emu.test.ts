// M13 security review: every callable, discovered from the built entry
// point, is called with malformed input, without auth, and by an owner
// aiming at another tenant. None may answer INTERNAL (an unhandled crash),
// succeed for an anonymous caller, or touch the other tenant (AC-017,
// FRD §7.2 "input validation on every endpoint").
import { execFileSync } from "node:child_process";
import * as path from "node:path";

import { getAuth } from "firebase-admin/auth";

import { FUNCTIONS_HOST, PROJECT_ID, admin, identityToolkit, resetEmulators, validInput } from "../testing/emulator";

const { db } = admin();

/** Callables that anyone may call (none today; listed here if added). */
const PUBLIC = new Set<string>();
/** Called before the restaurant exists (M01): signed-in but not yet an owner. */
const PRE_REGISTRATION = new Set(["completeRegistration"]);

interface Answer {
  status: number;
  error?: { status: string; message: string; details?: { code?: string } };
}

async function rawCall(name: string, token: string | null, data: unknown): Promise<Answer> {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (token) headers.authorization = `Bearer ${token}`;
  const res = await fetch(`http://${FUNCTIONS_HOST}/${PROJECT_ID}/asia-south1/${name}`, {
    method: "POST",
    headers,
    body: JSON.stringify({ data }),
  });
  const json = (await res.json().catch(() => ({}))) as { error?: Answer["error"] };
  return { status: res.status, error: json.error };
}

function listCallables(): string[] {
  const out = execFileSync(
    process.execPath,
    ["-e", "const m=require('./lib/index.js');console.log(JSON.stringify(Object.keys(m).filter(k=>m[k]&&m[k].__endpoint&&m[k].__endpoint.callableTrigger)))"],
    {
      cwd: path.resolve(__dirname, "../.."),
      env: { ...process.env, GCLOUD_PROJECT: PROJECT_ID, FIREBASE_CONFIG: JSON.stringify({ projectId: PROJECT_ID, storageBucket: `${PROJECT_ID}.appspot.com` }) },
    },
  ).toString();
  return JSON.parse(out.trim().split("\n").pop()!) as string[];
}

async function owner(email: string, name: string): Promise<{ token: string; rid: string }> {
  const up = await identityToolkit("signUp", { email, password: "Secret123!", returnSecureToken: true });
  const reg = await rawCall("completeRegistration", up.json.idToken as string, { ...validInput, restaurantName: name, mobile: `98${Math.floor(Math.random() * 1e8).toString().padStart(8, "0")}` });
  expect(reg.error).toBeUndefined();
  const user = await getAuth().getUserByEmail(email);
  await getAuth().updateUser(user.uid, { emailVerified: true });
  const signIn = await identityToolkit("signInWithPassword", { email, password: "Secret123!", returnSecureToken: true });
  const rid = (await db.collection("restaurants").where("ownerUid", "==", user.uid).get()).docs[0].id;
  return { token: signIn.json.idToken as string, rid };
}

let callables: string[] = [];
let a: { token: string; rid: string };
let b: { token: string; rid: string };

beforeAll(async () => {
  await resetEmulators();
  callables = listCallables();
  a = await owner("tenant-a@example.com", "Tenant A Kitchen");
  b = await owner("tenant-b@example.com", "Tenant B Kitchen");
  await db.doc(`restaurants/${b.rid}/categories/cb`).set({ name: "B only", sequence: 0, itemCount: 0, deletedAt: null });
}, 60_000);

it("finds the callables", () => {
  expect(callables.length).toBeGreaterThan(30);
  expect(callables).toEqual(expect.arrayContaining(["publishMenu", "exportMenu", "recordPaymentAndActivate", "adminListAuditLogs"]));
});

it("refuses anonymous callers on every callable", async () => {
  const bad: string[] = [];
  for (const name of callables) {
    if (PUBLIC.has(name)) continue;
    const r = await rawCall(name, null, { restaurantId: b.rid });
    if (r.error?.status !== "UNAUTHENTICATED") bad.push(`${name}: ${r.status} ${r.error?.status}`);
  }
  expect(bad).toEqual([]);
}, 120_000);

const MALFORMED: unknown[] = [
  null,
  "x",
  42,
  [],
  { restaurantId: { $gt: "" } },
  { restaurantId: "../../users", name: "x".repeat(20_000) },
  { restaurantId: "", categoryId: 7, itemId: [], planId: {}, cursor: "%%%" },
];

it("answers malformed input with a coded error, never INTERNAL", async () => {
  const bad: string[] = [];
  for (const name of callables) {
    for (const data of MALFORMED) {
      const r = await rawCall(name, a.token, data);
      if (r.error?.status === "INTERNAL" || (r.status >= 500 && r.error?.status !== "INTERNAL")) {
        bad.push(`${name} ${JSON.stringify(data).slice(0, 60)}: ${r.status} ${r.error?.status} ${r.error?.message}`);
      }
      // Error messages never carry stack traces or internal paths.
      if (r.error && /\bat \S+ \(|node_modules|\/workspace\/|lib\/.*\.js/.test(r.error.message)) {
        bad.push(`${name}: leaks "${r.error.message.slice(0, 80)}"`);
      }
    }
  }
  expect(bad).toEqual([]);
}, 600_000);

it("never lets tenant A act on tenant B's restaurant", async () => {
  const before = JSON.stringify((await db.doc(`restaurants/${b.rid}`).get()).data());
  const succeeded: string[] = [];
  for (const name of callables) {
    if (PRE_REGISTRATION.has(name)) continue;
    const data = {
      restaurantId: b.rid, categoryId: "cb", ids: ["cb"], name: "Hijack", confirmName: "Tenant B Kitchen",
      planId: "pro", billing: "monthly", slug: "hijacked-slug", priceMinor: 100, dietaryLabelId: "vegetarian",
    };
    const r = await rawCall(name, a.token, data);
    if (!r.error) succeeded.push(name);
  }
  // Only callables that don't take a target restaurant may succeed, and
  // they act on the caller's own data.
  const allowed = ["checkSlugAvailability"];
  expect(succeeded.filter((n) => !allowed.includes(n))).toEqual([]);
  const after = (await db.doc(`restaurants/${b.rid}`).get()).data()!;
  expect(after.status).toBe("active");
  expect(JSON.stringify(after)).toBe(before);
  expect((await db.collection(`restaurants/${b.rid}/categories`).get()).size).toBe(1);
  expect((await db.collection("upgradeRequests").where("restaurantId", "==", b.rid).get()).size).toBe(0);
}, 600_000);
