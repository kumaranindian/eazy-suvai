import {
  type DocumentReference,
  type DocumentSnapshot,
  type Firestore,
  type Query,
  type QuerySnapshot,
  type Transaction,
} from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions/v2";

import { getPlanFeatures, type PlanFeatures } from "../lib/plan-limits";
import { imagePathsOf, type DocEntry, type DraftInput, type DraftSource, type MenuSnapshot } from "./snapshot";

type Data = Record<string, unknown>;

/** Resolves Storage paths to public download URLs; unknown paths are left out. */
export type ImageUrlResolver = (paths: string[]) => Promise<Record<string, string>>;

/** The published version the draft is compared with. */
export interface CurrentVersion {
  n: number;
  snapshot: MenuSnapshot;
  source: DraftSource | null;
}

/** The draft plus everything publishing needs, minus image URLs. */
export interface LoadedDraft {
  input: Omit<DraftInput, "imageUrls">;
  limits: PlanFeatures;
  /** `themes/{themeId}.premium` (M10). */
  themePremium: boolean;
  planId: string;
  current: CurrentVersion | null;
}

/** Reads through a transaction when given one, so checks match the writes. */
export interface Reader {
  get(ref: DocumentReference): Promise<DocumentSnapshot>;
  query(q: Query): Promise<QuerySnapshot>;
}

export function readerFor(tx?: Transaction): Reader {
  if (tx) return { get: (ref) => tx.get(ref), query: (q) => tx.get(q) };
  return { get: (ref) => ref.get(), query: (q) => q.get() };
}

const dataOf = (s: DocumentSnapshot): Data | undefined => (s.exists ? (s.data() as Data) : undefined);
const entries = (q: QuerySnapshot): DocEntry[] => q.docs.map((d) => ({ id: d.id, data: d.data() as Data }));

function byId(q: QuerySnapshot): Record<string, Data> {
  const out: Record<string, Data> = {};
  for (const d of q.docs) out[d.id] = d.data() as Data;
  return out;
}

export function versionRef(db: Firestore, rid: string, n: number): DocumentReference {
  return db.doc(`restaurants/${rid}/versions/${n}`);
}

export function sourceRef(db: Firestore, rid: string, n: number): DocumentReference {
  return db.doc(`restaurants/${rid}/versions/${n}/private/source`);
}

/**
 * Reads a version and its private source.
 *
 * @return The version, or null when it does not exist (never published, or pruned).
 */
export async function loadVersion(db: Firestore, read: Reader, rid: string, n: number): Promise<CurrentVersion | null> {
  const [v, s] = await Promise.all([read.get(versionRef(db, rid, n)), read.get(sourceRef(db, rid, n))]);
  const data = dataOf(v);
  if (!data) return null;
  return { n, snapshot: data.snapshot as MenuSnapshot, source: (dataOf(s) as DraftSource | undefined) ?? null };
}

/**
 * Loads the draft of `restaurants/{rid}`: the root, every category and item
 * (deleted ones included, the builder filters), the platform labels and
 * tags, the chosen theme's tokens, the plan limits and the current version.
 *
 * @param db Firestore.
 * @param rid The restaurant.
 * @param tx Read inside this transaction.
 * @return The draft, or throws when the restaurant is gone.
 */
export async function loadDraft(db: Firestore, rid: string, tx?: Transaction): Promise<LoadedDraft> {
  const read = readerFor(tx);
  const root = db.doc(`restaurants/${rid}`);
  const restaurant = dataOf(await read.get(root)) ?? {};
  const themeId = typeof restaurant.themeId === "string" && /^[A-Za-z0-9_-]{1,64}$/.test(restaurant.themeId)
    ? restaurant.themeId
    : null;
  const planId = typeof restaurant.planId === "string" ? restaurant.planId : "free";
  const published = typeof restaurant.publishedVersion === "number" ? restaurant.publishedVersion : null;

  const [categories, items, labels, tags, theme, limits, current] = await Promise.all([
    read.query(root.collection("categories")),
    read.query(root.collection("items")),
    read.query(db.collection("dietaryLabels")),
    read.query(db.collection("itemTags")),
    themeId ? read.get(db.doc(`themes/${themeId}`)) : Promise.resolve(null),
    getPlanFeatures(async (path) => dataOf(await read.get(db.doc(path))), planId),
    published === null ? Promise.resolve(null) : loadVersion(db, read, rid, published),
  ]);

  return {
    input: {
      restaurant,
      categories: entries(categories),
      items: entries(items),
      labels: byId(labels),
      tags: byId(tags),
      themeTokens: theme ? (dataOf(theme)?.tokens ?? null) : null,
    },
    limits,
    themePremium: theme ? dataOf(theme)?.premium === true : false,
    planId,
    current,
  };
}

/**
 * The public token URL of a Storage object, as the Firebase SDKs and
 * `getDownloadURL` build it:
 * `https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{path}?alt=media&token={token}`
 * (the emulator host when `FIREBASE_STORAGE_EMULATOR_HOST` is set).
 */
export function downloadUrl(bucket: string, path: string, token: string, env: NodeJS.ProcessEnv = process.env): string {
  const host = env.FIREBASE_STORAGE_EMULATOR_HOST;
  const base = host ? `http://${host.replace(/^https?:\/\//, "")}` : "https://firebasestorage.googleapis.com";
  return `${base}/v0/b/${bucket}/o/${encodeURIComponent(path)}?alt=media&token=${encodeURIComponent(token)}`;
}

/**
 * Download URLs for renditions, from the `firebaseStorageDownloadTokens`
 * that `processImage` sets on each one (M02), 16 at a time. Reads the
 * object metadata with admin access (`getDownloadURL` goes through the
 * Firebase endpoint, which the emulator guards with storage.rules). A
 * missing file or token is logged and left out, so that image is simply
 * not published.
 */
export const storageUrlResolver: ImageUrlResolver = async (paths) => {
  const bucket = getStorage().bucket();
  const out: Record<string, string> = {};
  const queue = [...paths];
  const worker = async () => {
    for (let p = queue.shift(); p !== undefined; p = queue.shift()) {
      try {
        const [meta] = await bucket.file(p).getMetadata();
        const tokens = (meta.metadata as Record<string, unknown> | undefined)?.firebaseStorageDownloadTokens;
        const token = typeof tokens === "string" ? tokens.split(",")[0] : "";
        if (!token) throw new Error("no download token");
        out[p] = downloadUrl(bucket.name, p, token);
      } catch (e) {
        logger.warn("publishing: no download URL", { path: p, error: String(e) });
      }
    }
  };
  await Promise.all(Array.from({ length: Math.min(16, queue.length) }, worker));
  return out;
};

/**
 * URLs for every image the draft uses: from the current version's cache
 * (images are immutable per path), then [resolve] for the rest.
 *
 * @param draft The loaded draft.
 * @param resolve Resolver for paths not in the cache.
 * @param known URLs already resolved (for example before a transaction).
 * @return Path → URL.
 */
export async function imageUrlsFor(
  draft: LoadedDraft,
  resolve: ImageUrlResolver,
  known: Record<string, string> = {},
): Promise<Record<string, string>> {
  const cache = { ...(draft.current?.source?.imageUrls ?? {}), ...known };
  const paths = imagePathsOf(draft.input);
  const missing = paths.filter((p) => !cache[p]);
  const resolved = missing.length > 0 ? await resolve(missing) : {};
  const out: Record<string, string> = {};
  for (const p of paths) {
    const url = cache[p] ?? resolved[p];
    if (url) out[p] = url;
  }
  return out;
}
