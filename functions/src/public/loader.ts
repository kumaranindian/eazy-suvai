/**
 * Firestore reads for the public menu (architecture §3).
 *
 * Read order for a slug: `slugs/{slug}` → `restaurants/{rid}` (status and
 * the version pointer) → `versions/{n}` with `live/availability` and the
 * plan in one `getAll`. Publishing writes the version and moves the
 * pointer in one transaction and versions are immutable, so this order
 * never mixes two versions (AC-022).
 *
 * Only the published snapshot and the availability map are read from the
 * restaurant's subtree; draft documents and `versions/{n}/private/source`
 * are never touched (FR-045).
 */
import type { Firestore, Timestamp } from "firebase-admin/firestore";

import { removeBrandingFrom } from "../lib/plan-limits";
import type { MenuSnapshot } from "../publishing/snapshot";
import type { SitemapEntry } from "./seo";

type Data = Record<string, unknown>;

export type MenuLookup =
  | { kind: "live"; restaurantId: string; slug: string; version: number; snapshot: MenuSnapshot; availability: Record<string, boolean>; branding: boolean; publishedAt: Date | null }
  | { kind: "redirect"; slug: string }
  | { kind: "coming-soon"; name: string }
  | { kind: "unavailable"; name: string }
  | { kind: "gone" }
  | { kind: "not-found" };

/** FR-099: which statuses serve what. Grace period is `active` (live). */
const GONE_STATUSES = new Set(["deactivated", "deleted"]);

function toDate(v: unknown): Date | null {
  return v && typeof (v as Timestamp).toDate === "function" ? (v as Timestamp).toDate() : null;
}

function availabilityOf(data: Data | undefined): Record<string, boolean> {
  const items = data?.items;
  if (!items || typeof items !== "object") return {};
  const out: Record<string, boolean> = {};
  for (const [k, v] of Object.entries(items as Data)) if (typeof v === "boolean") out[k] = v;
  return out;
}

/**
 * Resolves a slug to what the page should show (FR-093, FR-099, BR-007).
 *
 * @param db Firestore.
 * @param slug A lower-case slug.
 * @return The lookup result.
 */
export async function loadMenu(db: Firestore, slug: string): Promise<MenuLookup> {
  const slugDoc = await db.doc(`slugs/${slug}`).get();
  const rid = slugDoc.get("restaurantId");
  if (!slugDoc.exists || typeof rid !== "string" || rid === "") return { kind: "not-found" };

  const rest = await db.doc(`restaurants/${rid}`).get();
  // The slug is held after deletion (FR-099: 12 months) even when the restaurant document is gone.
  if (!rest.exists) return { kind: "gone" };
  const r = rest.data() as Data;
  const status = typeof r.status === "string" ? r.status : "";
  const name = typeof r.name === "string" ? r.name : "";

  // Old slugs answer 301 to the current one (FR-093, AC-023). The root's
  // `slug` is the truth; `slugs/{slug}.current` is kept in step by changeSlug.
  if (typeof r.slug === "string" && r.slug !== "" && r.slug !== slug) return { kind: "redirect", slug: r.slug };

  if (GONE_STATUSES.has(status)) return { kind: "gone" };
  if (status !== "active") return { kind: "unavailable", name };
  const n = r.publishedVersion;
  if (typeof n !== "number") return { kind: "coming-soon", name };

  const planId = typeof r.planId === "string" && /^[A-Za-z0-9_-]{1,64}$/.test(r.planId) ? r.planId : "free";
  const [version, live, plan] = await db.getAll(
    db.doc(`restaurants/${rid}/versions/${n}`),
    db.doc(`restaurants/${rid}/live/availability`),
    db.doc(`plans/${planId}`),
  );
  const snapshot = version.get("snapshot") as MenuSnapshot | undefined;
  if (!version.exists || !snapshot) throw new Error(`restaurants/${rid}/versions/${n} is missing`);
  return {
    kind: "live",
    restaurantId: rid,
    slug,
    version: n,
    snapshot,
    availability: availabilityOf(live.data()),
    branding: !removeBrandingFrom(planId, plan.data()),
    publishedAt: toDate(r.publishedAt) ?? toDate(version.get("publishedAt")),
  };
}

export type QrLookup = { kind: "slug"; slug: string } | { kind: "gone" } | { kind: "not-found" };

/**
 * Resolves a QR short code to the restaurant's current slug (FR-048,
 * FR-051: it follows slug changes).
 *
 * @param db Firestore.
 * @param code An upper-case code.
 * @return The current slug, `gone` when the restaurant no longer exists, or `not-found`.
 */
export async function resolveQr(db: Firestore, code: string): Promise<QrLookup> {
  const qr = await db.doc(`qrCodes/${code}`).get();
  const rid = qr.get("restaurantId");
  if (!qr.exists || typeof rid !== "string" || rid === "") return { kind: "not-found" };
  const rest = await db.doc(`restaurants/${rid}`).get();
  const slug = rest.get("slug");
  if (!rest.exists || typeof slug !== "string" || slug === "") return { kind: "gone" };
  return { kind: "slug", slug };
}

/**
 * Active, published menus for `sitemap.xml` (FRD §7.6). Suspended,
 * deactivated, deleted and never-published restaurants are left out.
 *
 * @param db Firestore.
 * @return One entry per menu, by slug.
 */
export async function sitemapEntries(db: Firestore): Promise<SitemapEntry[]> {
  const snap = await db.collection("restaurants").where("status", "==", "active").select("slug", "publishedVersion", "publishedAt").get();
  return snap.docs
    .filter((d) => typeof d.get("publishedVersion") === "number" && typeof d.get("slug") === "string")
    .map((d) => ({ slug: d.get("slug") as string, lastmod: toDate(d.get("publishedAt")) }))
    .sort((a, b) => (a.slug < b.slug ? -1 : a.slug > b.slug ? 1 : 0));
}
