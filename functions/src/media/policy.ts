/**
 * Image rules shared by `processImage` (FR-102, architecture §4.4).
 *
 * Keep in sync with `packages/core/lib/src/media/image_object.dart`
 * (`ImagePurpose`, `ImageRejectReason`) and with `storage.rules`.
 */

/** Largest accepted upload, in bytes (FR-102). */
export const MAX_UPLOAD_BYTES = 5 * 1024 * 1024;

/** Decoded images above this many pixels are refused (decompression bombs). */
export const MAX_INPUT_PIXELS = 50_000_000;

/** Widths of the generated WebP renditions (FR-102). */
export const RENDITION_WIDTHS = [320, 640, 1280] as const;
export type RenditionKey = `w${(typeof RENDITION_WIDTHS)[number]}`;

export type ImagePurpose = "logo" | "cover" | "category" | "item";

/** Minimum dimensions per purpose (FR-102). */
export const MIN_DIMENSIONS: Record<ImagePurpose, { width: number; height: number }> = {
  logo: { width: 256, height: 256 },
  cover: { width: 1200, height: 400 },
  category: { width: 400, height: 400 },
  item: { width: 400, height: 400 },
};

/**
 * Reason codes written to `image.reason` when an upload is rejected.
 * The apps show a localized message for each (`ImageRejectReason`).
 */
export const RejectReason = {
  /** Not JPEG, PNG or WebP by content, or content and declared type differ. */
  unsupportedType: "unsupported-type",
  /** Larger than 5 MB, or more than MAX_INPUT_PIXELS pixels. */
  tooLarge: "too-large",
  /** Smaller than the purpose's minimum dimensions. */
  tooSmall: "too-small",
  /** Has a valid signature but cannot be decoded. */
  invalidImage: "invalid-image",
  /** Unexpected server failure. The original is kept for a retry. */
  processingFailed: "processing-failed",
} as const;
export type RejectReason = (typeof RejectReason)[keyof typeof RejectReason];

export type ImageFormat = "jpeg" | "png" | "webp";

export const CONTENT_TYPES: Record<ImageFormat, string> = {
  jpeg: "image/jpeg",
  png: "image/png",
  webp: "image/webp",
};

export const EXTENSIONS: Record<ImageFormat, string> = { jpeg: "jpg", png: "png", webp: "webp" };

/** `restaurants/{rid}/images/{imageId}/original.{ext}` */
const ORIGINAL_PATH = /^restaurants\/([A-Za-z0-9_-]{1,64})\/images\/([A-Za-z0-9_-]{16,64})\/original\.(jpg|png|webp)$/;

export interface OriginalPath {
  restaurantId: string;
  imageId: string;
  format: ImageFormat;
  /** Folder that holds the original and its renditions, without a trailing slash. */
  folder: string;
}

/** Parses an upload path, or returns null for any other object (renditions included). */
export function parseOriginalPath(name: string): OriginalPath | null {
  const m = ORIGINAL_PATH.exec(name);
  if (!m) return null;
  const format = (Object.keys(EXTENSIONS) as ImageFormat[]).find((f) => EXTENSIONS[f] === m[3])!;
  return {
    restaurantId: m[1],
    imageId: m[2],
    format,
    folder: `restaurants/${m[1]}/images/${m[2]}`,
  };
}

/** Path of the rendition `key` inside `folder`. */
export const renditionPath = (folder: string, width: number): string => `${folder}/w${width}.webp`;

export interface ImageTarget {
  purpose: ImagePurpose;
  /** Firestore document that holds the image object, inside the same restaurant. */
  docPath: string;
  /** Field of that document (only `logo`, `cover` or `image`). */
  field: "logo" | "cover" | "image";
  /** `items` documents also get `updatedAt`. */
  kind: "restaurant" | "category" | "item";
}

const DOC_ID = "[A-Za-z0-9_-]{1,128}";

/**
 * Checks the upload's custom metadata (`purpose`, `targetPath`, `field`)
 * against the allow-list below and the restaurant in the upload path.
 *
 * The allow-list is what stops an upload from writing any other field
 * (for example `status`) or any other restaurant's documents.
 *
 * @return The target, or null if the metadata is missing or not allowed.
 */
export function resolveTarget(
  restaurantId: string,
  metadata: Record<string, string> | undefined,
): ImageTarget | null {
  const purpose = metadata?.purpose;
  const targetPath = metadata?.targetPath;
  const field = metadata?.field;
  if (!purpose || !targetPath || !field) return null;

  const root = `restaurants/${restaurantId}`;
  switch (purpose) {
    case "logo":
    case "cover":
      if (targetPath !== root || field !== purpose) return null;
      return { purpose, docPath: root, field: purpose, kind: "restaurant" };
    case "category":
    case "item": {
      const sub = purpose === "category" ? "categories" : "items";
      const re = new RegExp(`^${root}/${sub}/${DOC_ID}$`);
      if (!re.test(targetPath) || field !== "image") return null;
      return { purpose, docPath: targetPath, field: "image", kind: purpose };
    }
    default:
      return null;
  }
}

/** True if `width` × `height` meets the purpose's minimum. */
export function meetsMinimum(purpose: ImagePurpose, width: number, height: number): boolean {
  const min = MIN_DIMENSIONS[purpose];
  return width >= min.width && height >= min.height;
}
