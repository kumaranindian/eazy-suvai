/**
 * Path routing for the `menu` Hosting site (architecture §3). Pure: no
 * Firestore, so every path shape is unit-tested.
 *
 * `/robots.txt` and `/favicon.ico` never reach the function (the Functions
 * Framework answers them itself), so they are static Hosting files:
 * `hosting/menu/robots.txt` is written by `scripts/write-robots.mjs`.
 */

export type Route =
  | { kind: "menu"; slug: string }
  | { kind: "qr"; code: string }
  | { kind: "sitemap" }
  | { kind: "redirect"; location: string; status: 301 }
  | { kind: "not-found" };

/** QR codes: 8 characters without 0/O/1/I/L (FR-047, M01 `qr-code.ts`). */
export const QR_CODE = /^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{8}$/;

/** Slug shape (FR-092; M01 `isValidSlug`), checked loosely before the lookup. */
const SLUG = /^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$/;

/**
 * Maps a request path to a route.
 *
 * - `/{slug}` → menu; `/{Slug}` or `/{slug}/` → 301 to the lower-case,
 *   slash-free form (the query string is kept).
 * - `/q/{code}` (any case) → QR lookup.
 * - `/sitemap.xml`.
 * - Anything else → not found.
 *
 * @param path The URL path (already without the query string).
 * @param query The raw query string including `?`, or "".
 * @return The route.
 */
export function routeOf(path: string, query = ""): Route {
  let p: string;
  try {
    p = decodeURIComponent(path);
  } catch {
    return { kind: "not-found" };
  }
  if (p === "/sitemap.xml") return { kind: "sitemap" };

  const qr = /^\/q\/([^/]+)\/?$/i.exec(p);
  if (qr) {
    const code = qr[1].toUpperCase();
    return QR_CODE.test(code) ? { kind: "qr", code } : { kind: "not-found" };
  }

  const m = /^\/([^/]+)(\/?)$/.exec(p);
  if (!m) return { kind: "not-found" };
  const slug = m[1].toLowerCase();
  if (!SLUG.test(slug)) return { kind: "not-found" };
  if (slug !== m[1] || m[2] === "/") return { kind: "redirect", status: 301, location: `/${slug}${query}` };
  return { kind: "menu", slug };
}
