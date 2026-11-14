import { crc32 } from "node:zlib";

import sharp from "sharp";

import { sniffImageFormat } from "./image-types";
import {
  MAX_INPUT_PIXELS,
  meetsMinimum,
  parseOriginalPath,
  resolveTarget,
} from "./policy";
import { ImageReadError, cleanOriginal, makeRenditions, readImageInfo } from "./renditions";
import { exifJpeg, image, pdfBytes } from "../testing/images";

const RID = "rest_1";
const ID = "abcdefghij0123456789";

describe("sniffImageFormat", () => {
  it("detects JPEG, PNG and WebP by content", async () => {
    expect(sniffImageFormat(await image(10, 10, "jpeg"))).toBe("jpeg");
    expect(sniffImageFormat(await image(10, 10, "png"))).toBe("png");
    expect(sniffImageFormat(await image(10, 10, "webp"))).toBe("webp");
  });

  it("rejects a renamed PDF, GIF, text and empty input", async () => {
    expect(sniffImageFormat(pdfBytes)).toBeNull();
    expect(sniffImageFormat(Buffer.from("GIF89a....."))).toBeNull();
    expect(sniffImageFormat(Buffer.from("hello world, not an image"))).toBeNull();
    expect(sniffImageFormat(Buffer.alloc(0))).toBeNull();
    // RIFF but not WEBP (a WAV file).
    expect(sniffImageFormat(Buffer.from("RIFF\0\0\0\0WAVEfmt "))).toBeNull();
  });
});

describe("parseOriginalPath", () => {
  it("accepts only original.{jpg,png,webp} under restaurants/{rid}/images/{id}/", () => {
    expect(parseOriginalPath(`restaurants/${RID}/images/${ID}/original.png`)).toEqual({
      restaurantId: RID,
      imageId: ID,
      format: "png",
      folder: `restaurants/${RID}/images/${ID}`,
    });
    expect(parseOriginalPath(`restaurants/${RID}/images/${ID}/original.jpg`)?.format).toBe("jpeg");
    for (const bad of [
      `restaurants/${RID}/images/${ID}/w320.webp`,
      `restaurants/${RID}/images/${ID}/original.gif`,
      `restaurants/${RID}/images/short/original.png`,
      `restaurants/${RID}/other/${ID}/original.png`,
      `users/u1/images/${ID}/original.png`,
      `restaurants/${RID}/images/${ID}/sub/original.png`,
    ]) {
      expect(parseOriginalPath(bad)).toBeNull();
    }
  });
});

describe("resolveTarget", () => {
  const meta = (purpose: string, targetPath: string, field: string) => ({ purpose, targetPath, field });

  it("maps each purpose to its document and field", () => {
    expect(resolveTarget(RID, meta("logo", `restaurants/${RID}`, "logo"))).toMatchObject({
      docPath: `restaurants/${RID}`,
      field: "logo",
      kind: "restaurant",
    });
    expect(resolveTarget(RID, meta("cover", `restaurants/${RID}`, "cover"))?.field).toBe("cover");
    expect(resolveTarget(RID, meta("item", `restaurants/${RID}/items/i1`, "image"))).toMatchObject({
      docPath: `restaurants/${RID}/items/i1`,
      kind: "item",
    });
    expect(resolveTarget(RID, meta("category", `restaurants/${RID}/categories/c1`, "image"))?.kind).toBe(
      "category",
    );
  });

  it("refuses another restaurant, other collections and other fields", () => {
    for (const m of [
      meta("logo", "restaurants/rest_2", "logo"),
      meta("item", "restaurants/rest_2/items/i1", "image"),
      meta("logo", `restaurants/${RID}`, "status"),
      meta("logo", `restaurants/${RID}`, "cover"),
      meta("item", `restaurants/${RID}/categories/c1`, "image"),
      meta("item", `restaurants/${RID}/items/i1/x/y`, "image"),
      meta("item", `restaurants/${RID}/versions/1`, "image"),
      meta("item", "users/u1", "image"),
      meta("avatar", `restaurants/${RID}`, "logo"),
    ]) {
      expect(resolveTarget(RID, m)).toBeNull();
    }
    expect(resolveTarget(RID, undefined)).toBeNull();
    expect(resolveTarget(RID, { purpose: "logo" })).toBeNull();
  });
});

describe("meetsMinimum (FR-102)", () => {
  it.each([
    ["logo", 256, 256, true],
    ["logo", 255, 256, false],
    ["cover", 1200, 400, true],
    ["cover", 1199, 400, false],
    ["cover", 1200, 399, false],
    ["item", 400, 400, true],
    ["category", 400, 399, false],
  ] as const)("%s %dx%d → %s", (purpose, w, h, ok) => {
    expect(meetsMinimum(purpose, w, h)).toBe(ok);
  });
});

describe("readImageInfo", () => {
  it("returns the format and upright dimensions", async () => {
    expect(await readImageInfo(await image(500, 300, "png"))).toEqual({
      format: "png",
      width: 500,
      height: 300,
    });
    // EXIF orientation 6 (rotate 90°): stored 600×400, shown 400×600.
    const rotated = await exifJpeg(600, 400, 6);
    expect(await readImageInfo(rotated)).toEqual({ format: "jpeg", width: 400, height: 600 });
  });

  it("rejects truncated data as invalid-image", async () => {
    const jpeg = await image(400, 400, "jpeg");
    await expect(readImageInfo(jpeg.subarray(0, 40))).rejects.toMatchObject({
      reason: "invalid-image",
    });
  });

  it("rejects decompression bombs as too-large", async () => {
    // A valid PNG whose header claims about 7072 × 7072 px.
    const side = Math.ceil(Math.sqrt(MAX_INPUT_PIXELS)) + 1;
    const png = await sharp({ create: { width: side, height: 1, channels: 3, background: "#fff" } })
      .png()
      .toBuffer();
    png.writeUInt32BE(side, 20); // IHDR height
    png.writeUInt32BE(crc32(png.subarray(12, 29)), 29); // IHDR CRC
    const err = await readImageInfo(png).catch((e) => e);
    expect(err).toBeInstanceOf(ImageReadError);
    expect(err.reason).toBe("too-large");
  });
});

describe("cleanOriginal", () => {
  it("removes EXIF and GPS, keeps the format and applies the orientation", async () => {
    const input = await exifJpeg(600, 400, 6);
    const before = await sharp(input).metadata();
    expect(before.exif).toBeDefined();
    expect(before.orientation).toBe(6);

    const out = await cleanOriginal(input, "jpeg");
    const after = await sharp(out).metadata();
    expect(after.format).toBe("jpeg");
    expect(after.exif).toBeUndefined();
    expect(after.xmp).toBeUndefined();
    expect(after.orientation).toBeUndefined();
    expect([after.width, after.height]).toEqual([400, 600]);
  });

  it("keeps PNG transparency", async () => {
    const png = await sharp({
      create: { width: 300, height: 300, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } },
    })
      .png()
      .toBuffer();
    const meta = await sharp(await cleanOriginal(png, "png")).metadata();
    expect(meta.format).toBe("png");
    expect(meta.hasAlpha).toBe(true);
  });
});

describe("makeRenditions", () => {
  it("writes WebP at 320, 640 and 1280 px without metadata", async () => {
    const out = await makeRenditions(await exifJpeg(2000, 1000, 1));
    expect(out.map((r) => [r.width, r.actualWidth, r.actualHeight])).toEqual([
      [320, 320, 160],
      [640, 640, 320],
      [1280, 1280, 640],
    ]);
    for (const r of out) {
      const meta = await sharp(r.data).metadata();
      expect(meta.format).toBe("webp");
      expect(meta.exif).toBeUndefined();
    }
  });

  it("never enlarges a small image", async () => {
    const out = await makeRenditions(await image(400, 400, "png"));
    expect(out.map((r) => r.actualWidth)).toEqual([320, 400, 400]);
  });
});
