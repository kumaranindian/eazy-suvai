/**
 * The `renderMenu` request handler (architecture §3), separate from the
 * Functions wrapper so it can be tested with plain objects.
 *
 * | Path | Result |
 * | --- | --- |
 * | `/{slug}` | 200 menu, or the FR-099 state page (404, 503, 410); old slug → 301 |
 * | `/q/{code}` | 302 to `/{slug}?src=qr` (FR-048) |
 * | `/sitemap.xml` | FRD §7.6 (`robots.txt` is a static Hosting file) |
 *
 * Every response that depends on data is `public, max-age=0, s-maxage=60`:
 * browsers revalidate, the Hosting CDN keeps it 60 s, so a publish or an
 * availability change shows within 60 s (FR-044). Each body gets an ETag
 * and a matching `If-None-Match` answers 304.
 */
import { createHash } from "node:crypto";

import type { Firestore } from "firebase-admin/firestore";

import { BODY_SCRIPT, HEAD_SCRIPT } from "./client-script";
import { loadMenu, resolveQr, sitemapEntries } from "./loader";
import { renderMenuPage } from "./render-menu";
import { routeOf } from "./routes";
import { sitemapXml } from "./seo";
import { STATE_STATUS, renderStatePage, type StateKind } from "./state-pages";

export const CACHE_PUBLIC = "public, max-age=0, s-maxage=60";
export const DEFAULT_MENU_BASE_URL = "https://menu.eazysuvai.com";

export interface MenuRequest {
  method: string;
  /** Path without the query string, for example `/spice-garden`. */
  path: string;
  /** The raw query string with its `?`, or "". */
  query: string;
  /** Lower-case header names. */
  headers: Record<string, string | undefined>;
}

export interface MenuResponse {
  status: number;
  headers: Record<string, string>;
  body: string;
}

export interface ServeDeps {
  /** The public origin, without a trailing slash (canonical, sitemap). */
  baseUrl?: string;
  /** "Now" for the "Open now" badge. */
  now?: Date;
  /** Allow `http:` images (the Storage emulator). */
  allowHttpImages?: boolean;
  /** Error logger. */
  logError?: (message: string, error: unknown) => void;
}

/**
 * The public menu origin of each Firebase project (canonical URLs, the
 * sitemap). Keep in step with `AppEnv.menuBaseUrl` in core and with
 * `ORIGINS` in `scripts/write-robots.mjs` (a test compares them).
 * Production is the default.
 */
export const MENU_ORIGINS: Readonly<Record<string, string>> = {
  "eazysuvai-prod": DEFAULT_MENU_BASE_URL,
  "eazy-suvai-dev": "https://eazy-suvai-dev-menu.web.app",
  "demo-eazysuvai": "http://127.0.0.1:5000",
};

function projectIdOf(env: NodeJS.ProcessEnv): string {
  if (env.GCLOUD_PROJECT) return env.GCLOUD_PROJECT;
  try {
    return (JSON.parse(env.FIREBASE_CONFIG ?? "{}") as { projectId?: string }).projectId ?? "";
  } catch {
    return "";
  }
}

/**
 * The menu origin: `MENU_BASE_URL` when set (an override), else the
 * project's entry in {@link MENU_ORIGINS}, else production.
 */
export function menuBaseUrl(env: NodeJS.ProcessEnv = process.env): string {
  const v = env.MENU_BASE_URL?.trim().replace(/\/$/, "");
  if (v && /^https?:\/\/[^/]+$/.test(v)) return v;
  return MENU_ORIGINS[projectIdOf(env)] ?? DEFAULT_MENU_BASE_URL;
}

const sha256 = (s: string) => createHash("sha256").update(s, "utf8").digest("base64");

/** Content-Security-Policy for HTML pages: only our two inline scripts may run. */
export function contentSecurityPolicy(allowHttpImages = false): string {
  return [
    "default-src 'none'",
    `script-src 'sha256-${sha256(HEAD_SCRIPT)}' 'sha256-${sha256(BODY_SCRIPT)}'`,
    "style-src 'unsafe-inline' https://fonts.googleapis.com",
    "font-src https://fonts.gstatic.com",
    `img-src https: data:${allowHttpImages ? " http:" : ""}`,
    "connect-src 'self'",
    "base-uri 'none'",
    "form-action 'none'",
    "frame-ancestors 'none'",
  ].join("; ");
}

function etagOf(body: string): string {
  return `W/"${createHash("sha1").update(body, "utf8").digest("base64url")}"`;
}

function html(status: number, body: string, deps: ServeDeps, extra: Record<string, string> = {}): MenuResponse {
  return {
    status,
    body,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": CACHE_PUBLIC,
      "Content-Security-Policy": contentSecurityPolicy(deps.allowHttpImages),
      "X-Content-Type-Options": "nosniff",
      "Referrer-Policy": "strict-origin-when-cross-origin",
      ...extra,
    },
  };
}

function statePage(kind: StateKind, deps: ServeDeps, o: { name?: string; locale?: string; retryUrl?: string } = {}): MenuResponse {
  const extra: Record<string, string> = { "X-Robots-Tag": "noindex" };
  if (kind === "unavailable") extra["Retry-After"] = "3600";
  if (kind === "error") extra["Cache-Control"] = "no-store";
  return html(STATE_STATUS[kind], renderStatePage(kind, o), deps, extra);
}

function redirect(status: 301 | 302, location: string): MenuResponse {
  return { status, body: "", headers: { "Location": location, "Cache-Control": CACHE_PUBLIC } };
}

function withEtag(req: MenuRequest, res: MenuResponse): MenuResponse {
  if (res.status !== 200 || res.body === "") return res;
  const etag = etagOf(res.body);
  const headers = { ...res.headers, ETag: etag };
  const inm = req.headers["if-none-match"];
  if (inm && inm.split(",").map((s) => s.trim()).includes(etag)) return { status: 304, headers, body: "" };
  return { ...res, headers };
}

/**
 * Handles one request to the menu site.
 *
 * @param db Firestore.
 * @param req The request.
 * @param deps Base URL, clock and logging.
 * @return The response (status, headers, body).
 */
export async function handleMenuRequest(db: Firestore, req: MenuRequest, deps: ServeDeps = {}): Promise<MenuResponse> {
  const baseUrl = deps.baseUrl ?? menuBaseUrl();
  if (req.method !== "GET" && req.method !== "HEAD") {
    return { status: 405, headers: { "Allow": "GET, HEAD", "Content-Type": "text/plain; charset=utf-8" }, body: "Method not allowed\n" };
  }
  const route = routeOf(req.path, req.query);
  try {
    switch (route.kind) {
    case "redirect":
      return redirect(route.status, route.location);
    case "not-found":
      return statePage("not-found", deps);
    case "sitemap":
      return withEtag(req, {
        status: 200,
        body: sitemapXml(baseUrl, await sitemapEntries(db)),
        headers: { "Content-Type": "application/xml; charset=utf-8", "Cache-Control": CACHE_PUBLIC },
      });
    case "qr": {
      const qr = await resolveQr(db, route.code);
      if (qr.kind === "slug") return redirect(302, `/${qr.slug}?src=qr`);
      return statePage(qr.kind, deps);
    }
    case "menu": {
      const m = await loadMenu(db, route.slug);
      switch (m.kind) {
      case "redirect":
        return redirect(301, `/${m.slug}${req.query}`);
      case "coming-soon":
      case "unavailable":
        return statePage(m.kind, deps, { name: m.name });
      case "gone":
      case "not-found":
        return statePage(m.kind, deps);
      case "live": {
        const body = renderMenuPage(m.snapshot, {
          availability: m.availability,
          branding: m.branding,
          canonicalUrl: `${baseUrl}/${m.slug}`,
          slug: m.slug,
          now: deps.now,
        });
        return withEtag(req, html(200, body, deps));
      }
      }
    }
    }
  } catch (e) {
    deps.logError?.(`renderMenu ${req.path}`, e);
    return statePage("error", deps, { retryUrl: `/${req.path.replace(/^\/+/, "")}${req.query}` });
  }
  return statePage("not-found", deps);
}
