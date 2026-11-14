// processImage on the emulators (M02, FR-102, AC-005).
//
// The first block calls the handler directly with an in-memory store and the
// Firestore emulator. The last test uploads to the Storage emulator and waits
// for the deployed trigger in the Functions emulator.
import { randomBytes } from "node:crypto";

import { Timestamp } from "firebase-admin/firestore";
import sharp from "sharp";

import { admin, resetEmulators, storageDownload, storageUpload } from "../testing/emulator";
import { exifJpeg, image, pdfBytes } from "../testing/images";
import { processUploadedImage, type ImageStore, type UploadedObject } from "./process-image";

const { db } = admin();
const RID = "rest_1";
const OTHER = "rest_2";

class MemoryStore implements ImageStore {
  files = new Map<string, { data: Buffer; contentType: string; cacheControl: string; metadata: Record<string, string> }>();
  async read(path: string) {
    const f = this.files.get(path);
    if (!f) throw new Error(`no such object ${path}`);
    return f.data;
  }
  async write(path: string, data: Buffer, o: { contentType: string; cacheControl: string; metadata: Record<string, string> }) {
    this.files.set(path, { data, ...o });
  }
  async remove(path: string) {
    this.files.delete(path);
  }
}

let store: MemoryStore;
const deps = () => ({ db, store });

const newId = () => randomBytes(10).toString("hex");

/** Puts `data` in the store and returns the finalize event for it. */
function upload(
  data: Buffer,
  opts: {
    rid?: string;
    ext?: "jpg" | "png" | "webp";
    contentType?: string;
    purpose?: string;
    targetPath?: string;
    field?: string;
    size?: number;
    timeCreated?: Date;
  } = {},
): UploadedObject {
  const rid = opts.rid ?? RID;
  const ext = opts.ext ?? "png";
  const name = `restaurants/${rid}/images/${newId()}/original.${ext}`;
  const contentType = opts.contentType ?? { jpg: "image/jpeg", png: "image/png", webp: "image/webp" }[ext];
  const purpose = opts.purpose ?? "logo";
  const metadata = {
    purpose,
    targetPath: opts.targetPath ?? `restaurants/${rid}`,
    field: opts.field ?? (purpose === "logo" || purpose === "cover" ? purpose : "image"),
  };
  store.files.set(name, { data, contentType, cacheControl: "", metadata });
  return { name, contentType, size: opts.size ?? data.length, metadata, timeCreated: opts.timeCreated ?? new Date() };
}

const field = async (path: string, name: string) => (await db.doc(path).get()).get(name);

beforeEach(async () => {
  await resetEmulators();
  store = new MemoryStore();
  await db.doc(`restaurants/${RID}`).set({ name: "Spice Garden", status: "active", logo: null, cover: null });
  await db.doc(`restaurants/${OTHER}`).set({ name: "Other", status: "active", logo: null });
  await db.doc(`restaurants/${RID}/items/i1`).set({ name: "Dosa", image: null });
  await db.doc(`restaurants/${RID}/categories/c1`).set({ name: "Breakfast", image: null });
});

describe("processUploadedImage", () => {
  it("accepts a PNG logo: renditions, clean original, ready object (AC-005)", async () => {
    const obj = upload(await image(512, 512, "png"));
    const out = await processUploadedImage(deps(), obj);
    expect(out.result).toBe("ready");

    const folder = obj.name.replace(/\/original\.png$/, "");
    const logo = await field(`restaurants/${RID}`, "logo");
    expect(logo).toMatchObject({
      path: obj.name,
      status: "ready",
      contentType: "image/png",
      width: 512,
      height: 512,
      renditions: { w320: `${folder}/w320.webp`, w640: `${folder}/w640.webp`, w1280: `${folder}/w1280.webp` },
    });
    expect(logo.uploadedAt).toBeInstanceOf(Timestamp);
    expect(await field(`restaurants/${RID}`, "draftUpdatedAt")).toBeInstanceOf(Timestamp);

    for (const w of [320, 640, 1280]) {
      const r = store.files.get(`${folder}/w${w}.webp`)!;
      expect(r.contentType).toBe("image/webp");
      expect(r.cacheControl).toContain("immutable");
      expect(r.metadata.firebaseStorageDownloadTokens).toBeTruthy();
      expect((await sharp(r.data).metadata()).format).toBe("webp");
    }
    expect(store.files.get(obj.name)!.metadata).toMatchObject({ processed: "true", purpose: "logo" });
  });

  it("strips EXIF and GPS from an item photo and stores upright dimensions", async () => {
    const obj = upload(await exifJpeg(900, 600, 6), {
      ext: "jpg",
      purpose: "item",
      targetPath: `restaurants/${RID}/items/i1`,
    });
    expect((await processUploadedImage(deps(), obj)).result).toBe("ready");

    const meta = await sharp(store.files.get(obj.name)!.data).metadata();
    expect(meta.exif).toBeUndefined();
    expect(meta.format).toBe("jpeg");
    const item = (await db.doc(`restaurants/${RID}/items/i1`).get()).data()!;
    expect(item.image).toMatchObject({ status: "ready", width: 600, height: 900, contentType: "image/jpeg" });
    expect(item.updatedAt).toBeInstanceOf(Timestamp);
    expect(await field(`restaurants/${RID}`, "draftUpdatedAt")).toBeInstanceOf(Timestamp);
  });

  it("accepts a WebP category image", async () => {
    const obj = upload(await image(400, 400, "webp"), {
      ext: "webp",
      purpose: "category",
      targetPath: `restaurants/${RID}/categories/c1`,
    });
    expect((await processUploadedImage(deps(), obj)).result).toBe("ready");
    expect((await field(`restaurants/${RID}/categories/c1`, "image")).status).toBe("ready");
  });

  it("rejects a file over 5 MB as too-large and deletes it (AC-005)", async () => {
    const obj = upload(await image(512, 512, "png"), { size: 6 * 1024 * 1024 });
    expect(await processUploadedImage(deps(), obj)).toEqual({ result: "rejected", reason: "too-large" });
    expect(await field(`restaurants/${RID}`, "logo")).toMatchObject({
      path: obj.name,
      status: "rejected",
      reason: "too-large",
    });
    expect(store.files.has(obj.name)).toBe(false);
  });

  it("rejects a renamed PDF as unsupported-type (AC-005)", async () => {
    const obj = upload(pdfBytes, { ext: "jpg" });
    expect(await processUploadedImage(deps(), obj)).toEqual({ result: "rejected", reason: "unsupported-type" });
    expect((await field(`restaurants/${RID}`, "logo")).reason).toBe("unsupported-type");
    expect(store.files.size).toBe(0);
  });

  it("rejects content that does not match the declared type", async () => {
    const png = await image(512, 512, "png");
    expect((await processUploadedImage(deps(), upload(png, { ext: "jpg" }))).result).toBe("rejected");
    const wrongHeader = upload(png, { ext: "png", contentType: "image/jpeg" });
    expect(await processUploadedImage(deps(), wrongHeader)).toEqual({
      result: "rejected",
      reason: "unsupported-type",
    });
  });

  it("rejects images below the minimum for their purpose", async () => {
    const small = upload(await image(300, 300, "png"), { purpose: "item", targetPath: `restaurants/${RID}/items/i1` });
    expect(await processUploadedImage(deps(), small)).toEqual({ result: "rejected", reason: "too-small" });

    const cover = upload(await image(1199, 400, "jpeg"), { ext: "jpg", purpose: "cover" });
    expect(await processUploadedImage(deps(), cover)).toEqual({ result: "rejected", reason: "too-small" });

    const logo = upload(await image(256, 256, "png"));
    expect((await processUploadedImage(deps(), logo)).result).toBe("ready");
  });

  it("rejects a corrupt image as invalid-image", async () => {
    const jpeg = await image(600, 600, "jpeg");
    const obj = upload(jpeg.subarray(0, 200), { ext: "jpg" });
    expect(await processUploadedImage(deps(), obj)).toEqual({ result: "rejected", reason: "invalid-image" });
  });

  it("never writes to another restaurant or to a field outside the allow-list", async () => {
    const png = await image(512, 512, "png");
    for (const meta of [
      { targetPath: `restaurants/${OTHER}` },
      { targetPath: `restaurants/${OTHER}/items/i1`, purpose: "item" },
      { field: "status" },
      { purpose: "avatar", field: "logo" },
    ]) {
      const obj = upload(png, meta);
      expect(await processUploadedImage(deps(), obj)).toEqual({ result: "skipped", why: "invalid-target" });
      expect(store.files.has(obj.name)).toBe(false);
    }
    expect(await field(`restaurants/${OTHER}`, "logo")).toBeNull();
    expect((await db.doc(`restaurants/${RID}`).get()).data()).toMatchObject({ status: "active", logo: null });
  });

  it("deletes uploads whose target document does not exist", async () => {
    const obj = upload(await image(512, 512, "png"), {
      purpose: "item",
      targetPath: `restaurants/${RID}/items/missing`,
    });
    expect(await processUploadedImage(deps(), obj)).toEqual({ result: "skipped", why: "target-missing" });
    expect(store.files.has(obj.name)).toBe(false);
  });

  it("ignores renditions, processed originals and redelivered events", async () => {
    const png = await image(512, 512, "png");
    const obj = upload(png);
    expect((await processUploadedImage(deps(), obj)).result).toBe("ready");
    // The re-encoded original fires the trigger again with `processed`.
    const rewritten = { ...obj, metadata: store.files.get(obj.name)!.metadata };
    expect(await processUploadedImage(deps(), rewritten)).toEqual({ result: "skipped", why: "already-processed" });
    // A rendition.
    const rendition = { ...obj, name: obj.name.replace("original.png", "w320.webp") };
    expect(await processUploadedImage(deps(), rendition)).toEqual({ result: "skipped", why: "not-an-original" });
    // The same event delivered twice.
    expect(await processUploadedImage(deps(), obj)).toEqual({ result: "skipped", why: "done" });
  });

  it("an older upload never replaces a newer one", async () => {
    const png = await image(512, 512, "png");
    const newer = upload(png, { timeCreated: new Date(Date.now()) });
    const older = upload(png, { timeCreated: new Date(Date.now() - 60_000) });
    expect((await processUploadedImage(deps(), newer)).result).toBe("ready");
    expect(await processUploadedImage(deps(), older)).toEqual({ result: "skipped", why: "superseded" });
    expect((await field(`restaurants/${RID}`, "logo")).path).toBe(newer.name);
    expect(store.files.has(older.name)).toBe(false);
  });
});

describe("processImage trigger (Storage + Functions emulators)", () => {
  it("processes an upload end to end", async () => {
    const id = newId();
    const name = `restaurants/${RID}/images/${id}/original.jpg`;
    await storageUpload(name, await exifJpeg(800, 800, 1), "image/jpeg", {
      purpose: "logo",
      targetPath: `restaurants/${RID}`,
      field: "logo",
    });

    let logo: { status?: string } | undefined;
    for (let i = 0; i < 60 && logo?.status !== "ready"; i++) {
      await new Promise((r) => setTimeout(r, 500));
      logo = await field(`restaurants/${RID}`, "logo");
    }
    expect(logo).toMatchObject({ path: name, status: "ready", width: 800, height: 800 });

    for (const w of [320, 640, 1280]) {
      const rendition = await storageDownload(`restaurants/${RID}/images/${id}/w${w}.webp`);
      expect((await sharp(rendition!).metadata()).format).toBe("webp");
    }
    const original = await storageDownload(name);
    expect((await sharp(original!).metadata()).exif).toBeUndefined();
  }, 60_000);
});
