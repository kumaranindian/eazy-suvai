/**
 * The analytics endpoint `collectEvent` (M09, FR-071 to FR-075).
 *
 * `POST /e` with `{type, slug, src, id?}` from the public menu's beacon
 * (`BEACON_SCRIPT` in `public/client-script.ts`). For a counted event, one
 * batch:
 * - increments `restaurants/{rid}/analyticsDaily/{yyyy-MM-dd}` (the day in
 *   the restaurant's time zone): `views`, `qrVisits`, `categoryTaps.{cid}`,
 *   `itemOpens.{iid}`;
 * - writes a raw event to `analyticsEvents` with `expireAt` = now + 90 days
 *   (Firestore TTL);
 * - increments `stats/platform.menuViews` / `qrVisits` (admin dashboard).
 *
 * Not counted: bots and empty user agents (FR-073), malformed or oversized
 * bodies, rate-limited clients, unknown or non-live menus, and ids that are
 * not in the live version (so nobody can add arbitrary keys to the daily
 * document). The IP address and the user agent are used in memory for
 * those checks and never stored (FR-075). The browser sends no session id.
 */
import { createHash, randomBytes } from "node:crypto";

import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";
import { isbot } from "isbot";
import { z } from "zod";

import type { MenuSnapshot } from "../publishing/snapshot";

export const EVENT_TTL_DAYS = 90;
export const MAX_BODY_BYTES = 1024;
const ID = /^[A-Za-z0-9_-]{1,64}$/;

export const eventSchema = z
  .object({
    type: z.enum(["view", "cat", "item"]),
    slug: z.string().regex(/^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$/),
    src: z.enum(["qr", "direct"]).default("direct"),
    id: z.string().regex(ID).optional(),
  })
  .strict()
  .refine((e) => (e.type === "view") === (e.id === undefined), { message: "id is required for cat and item, absent for view" });

export type MenuEvent = z.infer<typeof eventSchema>;

/** Parses a beacon body; null when it is not a valid event. */
export function parseEvent(body: string): MenuEvent | null {
  if (body.length === 0 || Buffer.byteLength(body) > MAX_BODY_BYTES) return null;
  let json: unknown;
  try {
    json = JSON.parse(body);
  } catch {
    return null;
  }
  const r = eventSchema.safeParse(json);
  return r.success ? r.data : null;
}

/** Crawlers, previewers, scripts and requests without a user agent (FR-073). */
export function isBotAgent(userAgent: string | undefined): boolean {
  const ua = (userAgent ?? "").trim();
  if (ua.length < 10) return true;
  return isbot(ua);
}

/**
 * `yyyy-MM-dd` of `at` in `timeZone` (FR-075: days in the restaurant's
 * zone; matches `TimeService.dayKey` in core). Unknown zones use UTC.
 */
export function dayKeyIn(at: Date, timeZone: string): string {
  // One formatter per zone for the instance's life (construction is the
  // expensive part; M13 load test).
  let f = dayFormatters.get(timeZone);
  if (f === undefined) {
    try {
      f = new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" });
    } catch {
      f = null;
    }
    dayFormatters.set(timeZone, f);
  }
  return f === null ? at.toISOString().slice(0, 10) : f.format(at);
}
const dayFormatters = new Map<string, Intl.DateTimeFormat | null>();

/**
 * A fixed-window counter per key, in memory only (one per function
 * instance). Keys are salted hashes, so even memory holds no raw IP.
 */
export class RateLimiter {
  private readonly hits = new Map<string, { start: number; n: number }>();
  private readonly salt = randomBytes(16);

  constructor(private readonly max: number, private readonly windowMs: number) {}

  /** Records a hit; false when `key` is over the limit in the current window. */
  allow(key: string, now: number): boolean {
    const k = createHash("sha256").update(this.salt).update(key).digest("base64url");
    const cur = this.hits.get(k);
    if (!cur || now - cur.start >= this.windowMs) {
      if (this.hits.size > 50_000) this.sweep(now);
      this.hits.set(k, { start: now, n: 1 });
      return true;
    }
    cur.n++;
    return cur.n <= this.max;
  }

  private sweep(now: number): void {
    for (const [k, v] of this.hits) if (now - v.start >= this.windowMs) this.hits.delete(k);
  }
}

/** What an event needs to know about its menu, cached briefly per instance. */
export interface LiveMenu {
  restaurantId: string;
  timezone: string;
  categoryIds: Set<string>;
  itemIds: Set<string>;
}

const CACHE_MS = 60_000;

/** Slug → live menu, for 60 s (a publish shows within the CDN's 60 s anyway). */
export class LiveMenuCache {
  private readonly entries = new Map<string, { at: number; menu: LiveMenu | null }>();

  async get(db: Firestore, slug: string, now: number): Promise<LiveMenu | null> {
    const hit = this.entries.get(slug);
    if (hit && now - hit.at < CACHE_MS) return hit.menu;
    const menu = await loadLiveMenu(db, slug);
    if (this.entries.size > 5_000) this.entries.clear();
    this.entries.set(slug, { at: now, menu });
    return menu;
  }
}

/** The live menu behind a current slug, or null (unknown, old slug, not active, not published). */
export async function loadLiveMenu(db: Firestore, slug: string): Promise<LiveMenu | null> {
  const s = await db.doc(`slugs/${slug}`).get();
  const rid = s.get("restaurantId");
  if (!s.exists || typeof rid !== "string" || rid === "") return null;
  const r = await db.doc(`restaurants/${rid}`).get();
  if (!r.exists || r.get("status") !== "active" || r.get("slug") !== slug) return null;
  const n = r.get("publishedVersion");
  if (typeof n !== "number") return null;
  const v = await db.doc(`restaurants/${rid}/versions/${n}`).get();
  const snap = v.get("snapshot") as MenuSnapshot | undefined;
  if (!snap) return null;
  const tz = r.get("timezone");
  return {
    restaurantId: rid,
    timezone: typeof tz === "string" && tz !== "" ? tz : snap.timezone,
    categoryIds: new Set(snap.categories.map((c) => c.id)),
    itemIds: new Set(snap.items.map((i) => i.id)),
  };
}

export interface CollectRequest {
  method: string;
  body: string;
  userAgent?: string;
  /** Used for rate limiting only; never stored. */
  ip?: string;
}

export type CollectResult =
  | { status: 204; counted: true; restaurantId: string; day: string }
  | { status: 204 | 400 | 404 | 405 | 413 | 429; counted: false; reason: string };

export interface CollectDeps {
  now?: () => Date;
  limiter?: RateLimiter;
  cache?: LiveMenuCache;
}

/** 120 events per minute per IP: a busy restaurant's shared Wi-Fi stays under it. */
export const defaultLimiter = new RateLimiter(120, 60_000);
export const defaultCache = new LiveMenuCache();

/**
 * Validates, filters and records one beacon event.
 *
 * @param db Firestore.
 * @param req Method, raw body, user agent and IP (the last two only checked).
 * @param deps Clock, limiter and cache (tests pass fresh ones).
 * @return Whether it was counted, and why not.
 */
export async function handleCollect(db: Firestore, req: CollectRequest, deps: CollectDeps = {}): Promise<CollectResult> {
  if (req.method !== "POST") return { status: 405, counted: false, reason: "method" };
  if (Buffer.byteLength(req.body) > MAX_BODY_BYTES) return { status: 413, counted: false, reason: "too-large" };
  // Bots get the same empty 204 as everyone: nothing to learn from probing.
  if (isBotAgent(req.userAgent)) return { status: 204, counted: false, reason: "bot" };
  const event = parseEvent(req.body);
  if (!event) return { status: 400, counted: false, reason: "malformed" };
  const now = (deps.now ?? (() => new Date()))();
  const limiter = deps.limiter ?? defaultLimiter;
  if (!limiter.allow(req.ip ?? "unknown", now.getTime())) return { status: 429, counted: false, reason: "rate-limited" };

  const menu = await (deps.cache ?? defaultCache).get(db, event.slug, now.getTime());
  if (!menu) return { status: 404, counted: false, reason: "unknown-menu" };
  if (event.type === "cat" && !menu.categoryIds.has(event.id!)) return { status: 204, counted: false, reason: "unknown-id" };
  if (event.type === "item" && !menu.itemIds.has(event.id!)) return { status: 204, counted: false, reason: "unknown-id" };

  const day = dayKeyIn(now, menu.timezone);
  const inc = FieldValue.increment(1);
  const daily: Record<string, unknown> = { day, updatedAt: FieldValue.serverTimestamp() };
  if (event.type === "view") {
    daily.views = inc;
    if (event.src === "qr") daily.qrVisits = inc;
  } else if (event.type === "cat") {
    daily.categoryTaps = { [event.id!]: inc };
  } else {
    daily.itemOpens = { [event.id!]: inc };
  }

  const batch = db.batch();
  batch.set(db.doc(`restaurants/${menu.restaurantId}/analyticsDaily/${day}`), daily, { merge: true });
  const raw: Record<string, unknown> = {
    restaurantId: menu.restaurantId,
    type: event.type,
    src: event.src,
    day,
    at: Timestamp.fromDate(now),
    expireAt: Timestamp.fromMillis(now.getTime() + EVENT_TTL_DAYS * 86_400_000),
  };
  if (event.id) raw.id = event.id;
  batch.create(db.collection("analyticsEvents").doc(), raw);
  if (event.type === "view") {
    // FRD §13 (M13): monthly totals too, by the platform's month (IST).
    const month = dayKeyIn(now, "Asia/Kolkata").slice(0, 7);
    const monthly: Record<string, unknown> = { views: inc };
    if (event.src === "qr") monthly.qrVisits = inc;
    const stats: Record<string, unknown> = { menuViews: inc, monthly: { [month]: monthly }, updatedAt: FieldValue.serverTimestamp() };
    if (event.src === "qr") stats.qrVisits = inc;
    batch.set(db.doc("stats/platform"), stats, { merge: true });
  }
  await batch.commit();
  return { status: 204, counted: true, restaurantId: menu.restaurantId, day };
}
