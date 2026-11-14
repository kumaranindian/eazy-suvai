import { randomUUID } from "node:crypto";

import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

import { sniffImageFormat } from "./image-types";
import {
  CONTENT_TYPES,
  MAX_UPLOAD_BYTES,
  RENDITION_WIDTHS,
  RejectReason,
  meetsMinimum,
  parseOriginalPath,
  renditionPath,
  resolveTarget,
  type ImageTarget,
  type OriginalPath,
  type RenditionKey,
} from "./policy";
import { ImageReadError, cleanOriginal, makeRenditions, readImageInfo } from "./renditions";

/** The bits of Cloud Storage that processing needs; faked in tests. */
export interface ImageStore {
  read(path: string): Promise<Buffer>;
  write(
    path: string,
    data: Buffer,
    options: { contentType: string; cacheControl: string; metadata: Record<string, string> },
  ): Promise<void>;
  /** Deletes an object; a missing object is not an error. */
  remove(path: string): Promise<void>;
}

/** The finalized object, as the Storage trigger reports it. */
export interface UploadedObject {
  name: string;
  contentType?: string;
  size: number | string;
  /** Custom metadata set by the uploader. */
  metadata?: Record<string, string>;
  timeCreated?: string | Date;
}

/** Image object stored on the target document (architecture §4.4). */
export type ImageObject =
  | { path: string; status: "processing"; uploadedAt: Timestamp }
  | { path: string; status: "rejected"; reason: RejectReason; uploadedAt: Timestamp }
  | {
      path: string;
      status: "ready";
      contentType: string;
      width: number;
      height: number;
      renditions: Record<RenditionKey, string>;
      uploadedAt: Timestamp;
    };

export type ProcessOutcome =
  | { result: "skipped"; why: string }
  | { result: "rejected"; reason: RejectReason }
  | { result: "ready"; image: ImageObject };

export interface ProcessDeps {
  db: Firestore;
  store: ImageStore;
}

/** Renditions are public and never change (new uploads get a new folder). */
const RENDITION_CACHE = "public, max-age=31536000, immutable";
const ORIGINAL_CACHE = "private, max-age=0";

/**
 * Validates one uploaded original and writes the result to its target
 * document (M02, FR-102):
 *
 * 1. Only `restaurants/{rid}/images/{id}/original.{ext}` uploads that are
 *    not marked `processed` are handled; renditions and the cleaned
 *    original (which also fire the trigger) are skipped.
 * 2. The custom metadata must name an allowed target inside the same
 *    restaurant (`resolveTarget`). Otherwise the upload is deleted.
 * 3. The target's field is set to `processing`, unless a newer upload has
 *    already claimed it.
 * 4. Size, real type (magic bytes), decodability and minimum dimensions
 *    are checked. A failure deletes the upload and sets `rejected` with a
 *    reason code.
 * 5. The original is re-encoded without metadata and WebP renditions at
 *    320/640/1280 px are written next to it. The field becomes `ready`,
 *    if it still points to this upload.
 */
export async function processUploadedImage(
  deps: ProcessDeps,
  object: UploadedObject,
): Promise<ProcessOutcome> {
  const original = parseOriginalPath(object.name);
  if (!original) return skipped("not-an-original");
  if (object.metadata?.processed === "true") return skipped("already-processed");

  const target = resolveTarget(original.restaurantId, object.metadata);
  if (!target) {
    logger.warn("processImage: invalid target metadata; deleting upload", {
      path: object.name,
      metadata: object.metadata,
    });
    await deps.store.remove(object.name);
    return skipped("invalid-target");
  }

  const uploadedAt = object.timeCreated
    ? Timestamp.fromDate(new Date(object.timeCreated))
    : Timestamp.now();
  const claim = await claimField(deps.db, target, object.name, uploadedAt);
  if (claim !== "claimed") {
    if (claim !== "done") await deps.store.remove(object.name);
    return skipped(claim);
  }

  let image: ImageObject;
  try {
    image = await validateAndRender(deps.store, object, original, target, uploadedAt);
  } catch (e) {
    const known = e instanceof ImageReadError;
    const reason = known ? e.reason : RejectReason.processingFailed;
    if (known) {
      logger.info("processImage: rejected", { path: object.name, reason, detail: e.message });
      await removeAll(deps.store, original, object.name);
    } else {
      // Keep the original so the image can be processed again later.
      logger.error("processImage: failed", { path: object.name, error: String(e) });
    }
    await finishField(deps.db, target, object.name, {
      path: object.name,
      status: "rejected",
      reason,
      uploadedAt,
    });
    return { result: "rejected", reason };
  }

  if (!(await finishField(deps.db, target, object.name, image))) {
    // A newer upload or a removal replaced this one while it was processed.
    // It was never `ready` anywhere, so nothing can reference its files.
    await removeAll(deps.store, original, object.name);
    return skipped("superseded");
  }
  return { result: "ready", image };
}

async function validateAndRender(
  store: ImageStore,
  object: UploadedObject,
  original: OriginalPath,
  target: ImageTarget,
  uploadedAt: Timestamp,
): Promise<ImageObject> {
  if (Number(object.size) > MAX_UPLOAD_BYTES) {
    throw new ImageReadError(RejectReason.tooLarge, `size ${object.size}`);
  }
  const declaredType = CONTENT_TYPES[original.format];
  if (object.contentType !== declaredType) {
    throw new ImageReadError(
      RejectReason.unsupportedType,
      `content type ${object.contentType} does not match .${original.format}`,
    );
  }

  const input = await store.read(object.name);
  if (input.length > MAX_UPLOAD_BYTES) {
    throw new ImageReadError(RejectReason.tooLarge, `size ${input.length}`);
  }
  const sniffed = sniffImageFormat(input);
  if (sniffed !== original.format) {
    throw new ImageReadError(
      RejectReason.unsupportedType,
      `content is ${sniffed ?? "not an image"}, declared ${original.format}`,
    );
  }

  const info = await readImageInfo(input);
  if (info.format !== sniffed) {
    throw new ImageReadError(RejectReason.unsupportedType, `decoded as ${info.format}`);
  }
  if (!meetsMinimum(target.purpose, info.width, info.height)) {
    throw new ImageReadError(
      RejectReason.tooSmall,
      `${info.width}x${info.height} below minimum for ${target.purpose}`,
    );
  }

  const [clean, renditions] = await Promise.all([
    cleanOriginal(input, info.format),
    makeRenditions(input),
  ]);

  const paths = {} as Record<RenditionKey, string>;
  for (const r of renditions) {
    const path = renditionPath(original.folder, r.width);
    await store.write(path, r.data, {
      contentType: "image/webp",
      cacheControl: RENDITION_CACHE,
      metadata: { firebaseStorageDownloadTokens: randomUUID() },
    });
    paths[`w${r.width}` as RenditionKey] = path;
  }
  // Written last: this fires the trigger again, which skips `processed`.
  await store.write(object.name, clean, {
    contentType: declaredType,
    cacheControl: ORIGINAL_CACHE,
    metadata: { ...(object.metadata ?? {}), processed: "true" },
  });

  return {
    path: object.name,
    status: "ready",
    contentType: declaredType,
    width: info.width,
    height: info.height,
    renditions: paths,
    uploadedAt,
  };
}

/**
 * Sets the target field to `processing` for this upload.
 *
 * @return `claimed`; `target-missing` if the document does not exist;
 *   `superseded` if a newer upload already owns the field; `done` if this
 *   upload was already processed (a redelivered event).
 */
async function claimField(
  db: Firestore,
  target: ImageTarget,
  path: string,
  uploadedAt: Timestamp,
): Promise<"claimed" | "target-missing" | "superseded" | "done"> {
  const ref = db.doc(target.docPath);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return "target-missing";
    const current = snap.get(target.field) as Partial<ImageObject> | null | undefined;
    if (current?.path === path) {
      if (current.status === "ready" || current.status === "rejected") return "done";
    } else if (
      current?.uploadedAt instanceof Timestamp &&
      current.uploadedAt.toMillis() > uploadedAt.toMillis()
    ) {
      return "superseded";
    }
    const value: ImageObject = { path, status: "processing", uploadedAt };
    tx.update(ref, { [target.field]: value });
    return "claimed";
  });
}

/**
 * Writes the final image object if the field still points to `path`.
 * A `ready` image also marks the draft as changed.
 */
async function finishField(
  db: Firestore,
  target: ImageTarget,
  path: string,
  value: ImageObject,
): Promise<boolean> {
  const ref = db.doc(target.docPath);
  const rootRef = db.doc(target.docPath.split("/").slice(0, 2).join("/"));
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = snap.exists ? (snap.get(target.field) as Partial<ImageObject> | null) : null;
    if (current?.path !== path) return false;

    const update: Record<string, unknown> = { [target.field]: value };
    const ready = value.status === "ready";
    if (ready && target.kind === "item") update.updatedAt = FieldValue.serverTimestamp();
    if (ready && target.kind === "restaurant") update.draftUpdatedAt = FieldValue.serverTimestamp();
    tx.update(ref, update);
    if (ready && target.kind !== "restaurant") {
      tx.update(rootRef, { draftUpdatedAt: FieldValue.serverTimestamp() });
    }
    return true;
  });
}

async function removeAll(store: ImageStore, original: OriginalPath, name: string): Promise<void> {
  await Promise.all([
    store.remove(name),
    ...RENDITION_WIDTHS.map((w) => store.remove(renditionPath(original.folder, w))),
  ]);
}

const skipped = (why: string): ProcessOutcome => ({ result: "skipped", why });
