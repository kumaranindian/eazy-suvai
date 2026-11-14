// M02: Storage rules for restaurants/{rid}/images (FR-102, AC-005, AC-017).
import { after, before, beforeEach, describe, it } from "node:test";

import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { doc, setDoc } from "firebase/firestore";
import { deleteObject, getBytes, ref, uploadBytes } from "firebase/storage";

import { adminClaims, createEnv, mfaAdminClaims, ownerClaims } from "./helpers.js";

const RID = "rest_1";
const OTHER = "rest_2";
const SUSPENDED = "rest_s";
const MB = 1024 * 1024;

let env;
let n = 0;
/** A fresh image folder id (16–64 url-safe characters). */
const newId = () => `img${String(++n).padStart(4, "0")}abcdefghijklm`;
const path = (rid = RID, id = newId(), file = "original.jpg") => `restaurants/${rid}/images/${id}/${file}`;

const logoMeta = (rid = RID) => ({ purpose: "logo", targetPath: `restaurants/${rid}`, field: "logo" });
/** Upload arguments for a JPEG. Pass `null` metadata to send none. */
const jpeg = (bytes = 1024, customMetadata = logoMeta()) => [
  new Uint8Array(bytes),
  customMetadata === null ? { contentType: "image/jpeg" } : { contentType: "image/jpeg", customMetadata },
];

before(async () => {
  env = await createEnv();
});
after(async () => {
  await env?.cleanup();
});
beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, `restaurants/${RID}`), { name: "Spice Garden", status: "active", ownerUid: "u1" });
    await setDoc(doc(db, `restaurants/${OTHER}`), { name: "Other", status: "active", ownerUid: "u2" });
    await setDoc(doc(db, `restaurants/${SUSPENDED}`), { name: "Paused", status: "suspended", ownerUid: "u3" });
  });
});

const owner = (uid = "u1", rid = RID, extra = {}) =>
  env.authenticatedContext(uid, { ...ownerClaims(rid), ...extra }).storage();

const upload = (storage, p, [data, meta]) => uploadBytes(ref(storage, p), data, meta);

describe("uploading restaurant images", () => {
  it("the owner can upload JPEG, PNG and WebP for every purpose (AC-005)", async () => {
    const s = owner();
    await assertSucceeds(upload(s, path(), jpeg()));
    await assertSucceeds(
      uploadBytes(ref(s, path(RID, newId(), "original.png")), new Uint8Array(10), {
        contentType: "image/png",
        customMetadata: { purpose: "cover", targetPath: `restaurants/${RID}`, field: "cover" },
      }),
    );
    await assertSucceeds(
      uploadBytes(ref(s, path(RID, newId(), "original.webp")), new Uint8Array(10), {
        contentType: "image/webp",
        customMetadata: { purpose: "item", targetPath: `restaurants/${RID}/items/i1`, field: "image" },
      }),
    );
    await assertSucceeds(
      upload(s, path(), jpeg(10, { purpose: "category", targetPath: `restaurants/${RID}/categories/c1`, field: "image" })),
    );
  });

  it("accepts exactly 5 MB and refuses anything larger (FR-102, AC-005)", async () => {
    await assertSucceeds(upload(owner(), path(), jpeg(5 * MB)));
    await assertFails(upload(owner(), path(), jpeg(5 * MB + 1)));
    await assertFails(upload(owner(), path(), jpeg(6 * MB)));
  });

  it("refuses other content types and mismatched extensions (AC-005)", async () => {
    const s = owner();
    for (const [file, contentType] of [
      ["original.jpg", "application/pdf"],
      ["original.jpg", "image/gif"],
      ["original.jpg", "image/png"],
      ["original.png", "image/jpeg"],
      ["original.webp", "image/png"],
      ["original.pdf", "application/pdf"],
      ["original.gif", "image/gif"],
    ]) {
      await assertFails(
        uploadBytes(ref(s, path(RID, newId(), file)), new Uint8Array(10), { contentType, customMetadata: logoMeta() }),
      );
    }
  });

  it("refuses any other file name or folder", async () => {
    const s = owner();
    await assertFails(upload(s, path(RID, newId(), "w320.webp"), jpeg()));
    await assertFails(upload(s, path(RID, newId(), "photo.jpg"), jpeg()));
    await assertFails(upload(s, path(RID, "short", "original.jpg"), jpeg()));
    await assertFails(upload(s, path(RID, "bad id with spaces!!!", "original.jpg"), jpeg()));
    await assertFails(upload(s, `restaurants/${RID}/images/original.jpg`, jpeg()));
    await assertFails(upload(s, `restaurants/${RID}/other/${newId()}/original.jpg`, jpeg()));
    await assertFails(upload(s, `restaurants/${RID}/images/${newId()}/x/original.jpg`, jpeg()));
  });

  it("requires metadata that targets an allowed field of the same restaurant", async () => {
    const s = owner();
    for (const customMetadata of [
      null,
      {},
      { purpose: "logo", targetPath: `restaurants/${RID}` },
      { ...logoMeta(), processed: "true" },
      { purpose: "logo", targetPath: `restaurants/${OTHER}`, field: "logo" },
      { purpose: "logo", targetPath: `restaurants/${RID}`, field: "status" },
      { purpose: "logo", targetPath: `restaurants/${RID}`, field: "cover" },
      { purpose: "avatar", targetPath: `restaurants/${RID}`, field: "avatar" },
      { purpose: "item", targetPath: `restaurants/${OTHER}/items/i1`, field: "image" },
      { purpose: "item", targetPath: `restaurants/${RID}/categories/c1`, field: "image" },
      { purpose: "item", targetPath: `restaurants/${RID}/items/i1/x/y`, field: "image" },
      { purpose: "item", targetPath: `restaurants/${RID}/items/i1`, field: "name" },
    ]) {
      await assertFails(upload(s, path(), jpeg(10, customMetadata)));
    }
  });

  it("another restaurant's owner cannot write to this restaurant's path (AC-017)", async () => {
    const other = owner("u2", OTHER);
    await assertFails(upload(other, path(RID), jpeg(10, logoMeta(RID))));
    await assertFails(upload(other, path(RID), jpeg(10, logoMeta(OTHER))));
  });

  it("unverified, suspended, signed-out, claimless and admin callers cannot upload", async () => {
    await assertFails(upload(owner("u1", RID, { email_verified: false }), path(), jpeg()));
    await assertFails(upload(owner("u3", SUSPENDED), path(SUSPENDED), jpeg(10, logoMeta(SUSPENDED))));
    await assertFails(upload(env.unauthenticatedContext().storage(), path(), jpeg()));
    await assertFails(upload(env.authenticatedContext("x", { email_verified: true }).storage(), path(), jpeg()));
    await assertFails(upload(env.authenticatedContext("a", mfaAdminClaims).storage(), path(), jpeg()));
    // A claim for the restaurant without the owner role.
    await assertFails(
      upload(env.authenticatedContext("u1", { email_verified: true, restaurantId: RID }).storage(), path(), jpeg()),
    );
  });

  it("nobody can overwrite or delete an image from a client", async () => {
    const p = path();
    await assertSucceeds(upload(owner(), p, jpeg()));
    await assertFails(upload(owner(), p, jpeg()));
    await assertFails(deleteObject(ref(owner(), p)));
  });
});

describe("reading restaurant images", () => {
  const p = `restaurants/${RID}/images/img0000abcdefghijklm/w320.webp`;
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(), p), new Uint8Array(4), { contentType: "image/webp" });
    });
  });

  it("the owner and an admin with TOTP can read", async () => {
    await assertSucceeds(getBytes(ref(owner(), p)));
    await assertSucceeds(getBytes(ref(env.authenticatedContext("a", mfaAdminClaims).storage(), p)));
  });

  it("other owners, admins without MFA and signed-out users cannot (AC-017)", async () => {
    await assertFails(getBytes(ref(owner("u2", OTHER), p)));
    await assertFails(getBytes(ref(owner("u1", RID, { email_verified: false }), p)));
    await assertFails(getBytes(ref(env.authenticatedContext("a", adminClaims).storage(), p)));
    await assertFails(getBytes(ref(env.unauthenticatedContext().storage(), p)));
  });
});
