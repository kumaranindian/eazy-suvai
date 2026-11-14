import sharp, { type Metadata } from "sharp";

import {
  MAX_INPUT_PIXELS,
  RENDITION_WIDTHS,
  RejectReason,
  type ImageFormat,
} from "./policy";

/** What sharp reads from an image, after applying the EXIF orientation. */
export interface ImageInfo {
  format: ImageFormat;
  /** Display width (rotated by the EXIF orientation if needed). */
  width: number;
  height: number;
}

/** Thrown when an image cannot be read; carries the reject reason. */
export class ImageReadError extends Error {
  constructor(readonly reason: RejectReason, message: string) {
    super(message);
  }
}

const open = (input: Buffer) =>
  sharp(input, { limitInputPixels: MAX_INPUT_PIXELS, failOn: "error", pages: 1 });

/**
 * Reads the decoded format and display dimensions.
 *
 * @throws ImageReadError `too-large` above MAX_INPUT_PIXELS, `invalid-image`
 *   if the data cannot be decoded, `unsupported-type` for other formats.
 */
export async function readImageInfo(input: Buffer): Promise<ImageInfo> {
  let meta: Metadata;
  try {
    meta = await open(input).metadata();
  } catch (e) {
    // sharp refuses to read headers above limitInputPixels.
    const reason = /pixel limit/i.test(String(e)) ? RejectReason.tooLarge : RejectReason.invalidImage;
    throw new ImageReadError(reason, `metadata: ${String(e)}`);
  }
  const format = meta.format;
  if (format !== "jpeg" && format !== "png" && format !== "webp") {
    throw new ImageReadError(RejectReason.unsupportedType, `decoded format ${format}`);
  }
  const { width, height } = meta;
  if (!width || !height) throw new ImageReadError(RejectReason.invalidImage, "no dimensions");
  if (width * height > MAX_INPUT_PIXELS) {
    throw new ImageReadError(RejectReason.tooLarge, `${width}x${height} exceeds pixel limit`);
  }
  // EXIF orientations 5–8 rotate by 90°, so width and height swap.
  const swap = (meta.orientation ?? 1) >= 5;
  return { format, width: swap ? height : width, height: swap ? width : height };
}

/**
 * Re-encodes the original in its own format, upright, with all metadata
 * (EXIF, GPS, XMP, comments) removed (FR-102, FRD §7.2).
 */
export async function cleanOriginal(input: Buffer, format: ImageFormat): Promise<Buffer> {
  const img = open(input).autoOrient();
  try {
    switch (format) {
      case "jpeg":
        return await img.jpeg({ quality: 90, mozjpeg: true }).toBuffer();
      case "png":
        return await img.png({ compressionLevel: 9 }).toBuffer();
      case "webp":
        return await img.webp({ quality: 90 }).toBuffer();
    }
  } catch (e) {
    throw new ImageReadError(RejectReason.invalidImage, `re-encode: ${String(e)}`);
  }
}

export interface Rendition {
  /** Requested width (320, 640 or 1280). */
  width: number;
  /** Actual width: never upscaled, so it can be smaller than `width`. */
  actualWidth: number;
  actualHeight: number;
  data: Buffer;
}

/**
 * WebP renditions at 320, 640 and 1280 px wide (FR-102). Images narrower
 * than a width are not enlarged; that rendition keeps the original width.
 */
export async function makeRenditions(input: Buffer): Promise<Rendition[]> {
  const out: Rendition[] = [];
  for (const width of RENDITION_WIDTHS) {
    const { data, info } = await open(input)
      .autoOrient()
      .resize({ width, withoutEnlargement: true })
      .webp({ quality: 80 })
      .toBuffer({ resolveWithObject: true });
    out.push({ width, actualWidth: info.width, actualHeight: info.height, data });
  }
  return out;
}
