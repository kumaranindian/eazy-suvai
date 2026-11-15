/**
 * The published menu snapshot (M06): a pure builder, the change summary and
 * the publish validation. No Firestore here, so every rule is unit-tested;
 * `draft-reader.ts` loads the inputs and `publish.ts` writes the results.
 *
 * The snapshot is what the public menu (M07) renders and is stored in
 * `restaurants/{rid}/versions/{n}.snapshot`. Its shape is a cross-module
 * contract (master plan, Cross-module notes): change it only together with
 * the renderer and bump {@link SNAPSHOT_SCHEMA}.
 */
import { resolveTheme, parseThemeSettings, parseThemeTokens, type ResolvedTheme, type ThemeSettings, type ThemeTokens } from "../theme";

type Data = Record<string, unknown>;

/** Bumped when the snapshot shape changes incompatibly. */
export const SNAPSHOT_SCHEMA = 1;

/** Published versions kept per restaurant (FR-096). */
export const VERSIONS_KEPT = 10;

/** A Firestore document is at most 1 MiB; leave room for the other fields. */
export const MAX_SNAPSHOT_BYTES = 900_000;

export const WEEKDAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"] as const;
export type Weekday = (typeof WEEKDAYS)[number];

export const SOCIAL_KEYS = ["instagram", "facebook", "x", "youtube", "googleMaps"] as const;

/** Public download URLs of one image's renditions (architecture §4.4). */
export interface SnapshotImage {
  width: number;
  height: number;
  w320: string;
  w640: string;
  w1280: string;
}

export interface SnapshotContact {
  phone?: string;
  email?: string;
  address?: string;
  city?: string;
  postalCode?: string;
  website?: string;
  social?: Partial<Record<(typeof SOCIAL_KEYS)[number], string>>;
}

/** Public restaurant details, with hidden groups already removed (FR-013, FR-014). */
export interface SnapshotProfile {
  name: string;
  businessType: string;
  description?: string;
  logo?: SnapshotImage;
  cover?: SnapshotImage;
  contact: SnapshotContact;
  /** One string per weekday (architecture §4.2); absent when hidden or not set. */
  openingHours?: Record<Weekday, string>;
}

export interface SnapshotTheme {
  themeId: string | null;
  /** The theme's tokens, copied at publish so later admin edits don't change this version. */
  tokens: ThemeTokens;
  /** The owner's overrides. */
  settings: ThemeSettings;
  /** `resolveTheme(tokens, settings)` without `issues`: the contrast-fixed colours (FR-060). */
  resolved: Omit<ResolvedTheme, "issues">;
}

export interface SnapshotLabel {
  id: string;
  name: string;
  icon: string | null;
  color: string | null;
}

export interface SnapshotCategory {
  id: string;
  name: string;
  description?: string;
  image?: SnapshotImage;
  sequence: number;
}

export interface SnapshotItem {
  id: string;
  categoryId: string;
  name: string;
  description?: string;
  image?: SnapshotImage;
  /** Integer minor units of `snapshot.currency` (BR-019). */
  priceMinor: number;
  dietaryLabel: SnapshotLabel | null;
  tags: SnapshotLabel[];
  /** At publish time. The live value is `live/availability.items[id]` (FR-095). */
  available: boolean;
  featured: boolean;
  sequence: number;
}

export interface MenuSnapshot {
  schema: number;
  profile: SnapshotProfile;
  theme: SnapshotTheme;
  /** Active categories in display order. */
  categories: SnapshotCategory[];
  /** Visible items in display order (by category order, then item order). */
  items: SnapshotItem[];
  /** ISO 4217 (BR-016). */
  currency: string;
  /** BCP 47 locale for number and date formatting, for example `en-IN`. */
  locale: string;
  /** IANA time zone for opening hours. */
  timezone: string;
}

/** One Firestore document: id plus data. */
export interface DocEntry {
  id: string;
  data: Data;
}

/** Everything the builder reads. */
export interface DraftInput {
  /** `restaurants/{rid}` data. */
  restaurant: Data;
  /** All `categories` docs (deleted ones are filtered here). */
  categories: DocEntry[];
  /** All `items` docs. */
  items: DocEntry[];
  /** `dietaryLabels/{id}` data by id. */
  labels: Record<string, Data>;
  /** `itemTags/{id}` data by id. */
  tags: Record<string, Data>;
  /** `themes/{themeId}.tokens`, or null when no theme is chosen or it is missing. */
  themeTokens: unknown;
  /** Storage path → public URL for every rendition that could be resolved. */
  imageUrls: Record<string, string>;
}

// ---- helpers ---------------------------------------------------------------

function str(v: unknown): string | undefined {
  return typeof v === "string" && v.trim() !== "" ? v.trim() : undefined;
}

function isLive(d: Data): boolean {
  return d.deletedAt === null || d.deletedAt === undefined;
}

function seqOf(d: Data): number {
  return typeof d.sequence === "number" ? d.sequence : 0;
}

/** Display order: `sequence` ascending, ties by id (as `compareSequenced` in core). */
export function compareSequenced(a: DocEntry, b: DocEntry): number {
  return seqOf(a.data) - seqOf(b.data) || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
}

/** Rendition paths of a `ready` image object, or []. */
export function renditionPaths(image: unknown): string[] {
  if (!image || typeof image !== "object") return [];
  const img = image as Data;
  if (img.status !== "ready") return [];
  const r = img.renditions as Data | undefined;
  if (!r) return [];
  return [r.w320, r.w640, r.w1280].filter((p): p is string => typeof p === "string");
}

/** Every rendition path the draft's public content refers to. */
export function imagePathsOf(input: Pick<DraftInput, "restaurant" | "categories" | "items">): string[] {
  const out = new Set<string>();
  const add = (img: unknown) => renditionPaths(img).forEach((p) => out.add(p));
  add(input.restaurant.logo);
  add(input.restaurant.cover);
  for (const c of input.categories) add(c.data.image);
  for (const i of input.items) add(i.data.image);
  return [...out];
}

/**
 * A `ready` image with all three rendition URLs, or undefined. Images still
 * processing, rejected, or whose files can't be resolved are left out.
 */
export function snapshotImage(image: unknown, urls: Record<string, string>): SnapshotImage | undefined {
  if (!image || typeof image !== "object") return undefined;
  const img = image as Data;
  const r = img.renditions as Data | undefined;
  if (img.status !== "ready" || !r) return undefined;
  const url = (p: unknown) => (typeof p === "string" ? urls[p] : undefined);
  const w320 = url(r.w320);
  const w640 = url(r.w640);
  const w1280 = url(r.w1280);
  if (!w320 || !w640 || !w1280) return undefined;
  return {
    width: typeof img.width === "number" ? img.width : 0,
    height: typeof img.height === "number" ? img.height : 0,
    w320,
    w640,
    w1280,
  };
}

/** `en-{country}` (FRD §6.3: English in the MVP), or `en`. */
export function localeFor(country: unknown): string {
  return typeof country === "string" && /^[A-Z]{2}$/.test(country) ? `en-${country}` : "en";
}

/** Whether a visibility group is shown: a missing flag means shown (M03). */
export function isShown(visibility: unknown, group: "phone" | "email" | "address" | "hours" | "social"): boolean {
  if (!visibility || typeof visibility !== "object") return true;
  return (visibility as Data)[group] !== false;
}

function contactOf(restaurant: Data): SnapshotContact {
  const c = (restaurant.contact ?? {}) as Data;
  const v = restaurant.visibility;
  const out: SnapshotContact = {};
  if (isShown(v, "phone") && str(c.phone)) out.phone = str(c.phone);
  if (isShown(v, "email") && str(c.email)) out.email = str(c.email);
  if (isShown(v, "address")) {
    if (str(c.address)) out.address = str(c.address);
    if (str(c.city)) out.city = str(c.city);
    if (str(c.postalCode)) out.postalCode = str(c.postalCode);
  }
  // The website sits with the social links in the profile form (M03).
  if (isShown(v, "social")) {
    if (str(c.website)) out.website = str(c.website);
    const s = (c.social ?? {}) as Data;
    const social: SnapshotContact["social"] = {};
    for (const k of SOCIAL_KEYS) {
      const link = str(s[k]);
      if (link) social[k] = link;
    }
    if (Object.keys(social).length > 0) out.social = social;
  }
  return out;
}

function hoursOf(restaurant: Data): Record<Weekday, string> | undefined {
  const h = restaurant.openingHours;
  if (!isShown(restaurant.visibility, "hours") || !h || typeof h !== "object") return undefined;
  const out = {} as Record<Weekday, string>;
  for (const d of WEEKDAYS) {
    const v = (h as Data)[d];
    out[d] = typeof v === "string" ? v : "";
  }
  return out;
}

function labelOf(id: string, data: Data | undefined): SnapshotLabel | null {
  if (!data) return null;
  return {
    id,
    name: typeof data.name === "string" ? data.name : id,
    icon: typeof data.icon === "string" ? data.icon : null,
    color: typeof data.color === "string" ? data.color : null,
  };
}

function themeOf(restaurant: Data, themeTokens: unknown): SnapshotTheme {
  const themeId = typeof restaurant.themeId === "string" ? restaurant.themeId : null;
  // No theme chosen (or it is gone): DEFAULT_TOKENS, through parseThemeTokens.
  const tokens = parseThemeTokens(themeId ? themeTokens : null);
  const settings = parseThemeSettings(restaurant.themeSettings);
  const resolved: Partial<ResolvedTheme> = resolveTheme(tokens, settings);
  delete resolved.issues;
  return { themeId, tokens, settings, resolved: resolved as Omit<ResolvedTheme, "issues"> };
}

/** Active, non-deleted categories not hidden over the plan limit (FR-101), in display order. */
export function publicCategories(categories: readonly DocEntry[]): DocEntry[] {
  return categories
    .filter((c) => isLive(c.data) && c.data.active !== false && c.data.hiddenOverLimit !== true)
    .sort(compareSequenced);
}

/** Non-deleted, not over-limit items whose category is public, in display order. */
export function publicItems(items: readonly DocEntry[], categories: readonly DocEntry[]): DocEntry[] {
  const order = new Map(publicCategories(categories).map((c, i) => [c.id, i]));
  return items
    .filter((i) => isLive(i.data) && i.data.hiddenOverLimit !== true && order.has(String(i.data.categoryId)))
    .sort((a, b) => order.get(String(a.data.categoryId))! - order.get(String(b.data.categoryId))! || compareSequenced(a, b));
}

/**
 * Builds the public snapshot from the draft (FR-062, BR-008).
 *
 * - Profile: name, business type, description, ready logo and cover, and
 *   only the contact groups and hours the owner shows (`visibility`).
 * - Theme: the theme's tokens copied now, the overrides, and the
 *   contrast-fixed colours.
 * - Categories: non-deleted and active, by `sequence` then id.
 * - Items: non-deleted, not `hiddenOverLimit`, in a public category, by
 *   category order then `sequence` then id. Unknown tag ids are dropped;
 *   retired labels and tags stay (FR-104).
 * - Images: only `ready` ones whose three renditions have URLs.
 *
 * @param input The draft and its lookups.
 * @return The snapshot.
 */
export function buildSnapshot(input: DraftInput): MenuSnapshot {
  const r = input.restaurant;
  const urls = input.imageUrls;

  const profile: SnapshotProfile = {
    name: str(r.name) ?? "",
    businessType: str(r.businessType) ?? "other",
    contact: contactOf(r),
  };
  const description = str(r.description);
  if (description) profile.description = description;
  const logo = snapshotImage(r.logo, urls);
  if (logo) profile.logo = logo;
  const cover = snapshotImage(r.cover, urls);
  if (cover) profile.cover = cover;
  const hours = hoursOf(r);
  if (hours) profile.openingHours = hours;

  const categories: SnapshotCategory[] = publicCategories(input.categories).map((c) => {
    const out: SnapshotCategory = { id: c.id, name: str(c.data.name) ?? "", sequence: seqOf(c.data) };
    const d = str(c.data.description);
    if (d) out.description = d;
    const img = snapshotImage(c.data.image, urls);
    if (img) out.image = img;
    return out;
  });

  const items: SnapshotItem[] = publicItems(input.items, input.categories).map((i) => {
    const d = i.data;
    const labelId = typeof d.dietaryLabelId === "string" ? d.dietaryLabelId : "";
    const tagIds = Array.isArray(d.tagIds) ? d.tagIds.filter((t): t is string => typeof t === "string") : [];
    const out: SnapshotItem = {
      id: i.id,
      categoryId: String(d.categoryId),
      name: str(d.name) ?? "",
      priceMinor: typeof d.priceMinor === "number" ? d.priceMinor : 0,
      dietaryLabel: labelOf(labelId, input.labels[labelId]),
      tags: [...new Set(tagIds)]
        .map((t) => labelOf(t, input.tags[t]))
        .filter((t): t is SnapshotLabel => t !== null),
      available: d.available !== false,
      featured: d.featured === true,
      sequence: seqOf(d),
    };
    const desc = str(d.description);
    if (desc) out.description = desc;
    const img = snapshotImage(d.image, urls);
    if (img) out.image = img;
    return out;
  });

  return {
    schema: SNAPSHOT_SCHEMA,
    profile,
    theme: themeOf(r, input.themeTokens),
    categories,
    items,
    currency: str(r.currency) ?? "",
    locale: localeFor(r.country),
    timezone: str(r.timezone) ?? "UTC",
  };
}

// ---- change summary (FR-065) ----------------------------------------------

/** A category or item named in the change summary. */
export interface ChangeRef {
  id: string;
  name: string;
}

export interface ChangeLists {
  added: ChangeRef[];
  changed: ChangeRef[];
  removed: ChangeRef[];
}

export interface ChangeSummary {
  /** No version is published yet: everything is "added". */
  firstPublish: boolean;
  profileChanged: boolean;
  themeChanged: boolean;
  categories: ChangeLists;
  items: ChangeLists;
}

/** JSON with sorted keys, for comparing plain data. */
export function stableJson(v: unknown): string {
  if (Array.isArray(v)) return `[${v.map(stableJson).join(",")}]`;
  if (v && typeof v === "object") {
    const o = v as Data;
    return `{${Object.keys(o)
      .filter((k) => o[k] !== undefined)
      .sort()
      .map((k) => `${JSON.stringify(k)}:${stableJson(o[k])}`)
      .join(",")}}`;
  }
  return JSON.stringify(v) ?? "null";
}

function diffById<T extends { id: string; name: string }>(
  before: readonly T[],
  after: readonly T[],
  key: (x: T) => string,
): ChangeLists {
  const old = new Map(before.map((x) => [x.id, x]));
  const now = new Map(after.map((x) => [x.id, x]));
  const ref = (x: T): ChangeRef => ({ id: x.id, name: x.name });
  return {
    added: after.filter((x) => !old.has(x.id)).map(ref),
    changed: after.filter((x) => old.has(x.id) && key(old.get(x.id)!) !== key(x)).map(ref),
    removed: before.filter((x) => !now.has(x.id)).map(ref),
  };
}

/**
 * Compares two snapshots by id (FR-065): categories and items added,
 * changed (any public field, including position) and removed, plus whether
 * the profile or the theme changed. Availability is ignored: it is live
 * (FR-095) and never a reason to publish.
 *
 * @param before The published snapshot, or null before the first publish.
 * @param after The snapshot about to be published.
 * @return The summary.
 */
export function diffSnapshots(before: MenuSnapshot | null, after: MenuSnapshot): ChangeSummary {
  const prev = before ?? null;
  const itemKey = (i: SnapshotItem) => stableJson({ ...i, available: undefined });
  return {
    firstPublish: prev === null,
    profileChanged:
      prev !== null &&
      stableJson([prev.profile, prev.currency, prev.locale, prev.timezone]) !==
        stableJson([after.profile, after.currency, after.locale, after.timezone]),
    themeChanged:
      prev !== null &&
      stableJson([prev.theme.themeId, prev.theme.tokens, prev.theme.settings]) !==
        stableJson([after.theme.themeId, after.theme.tokens, after.theme.settings]),
    categories: diffById(prev?.categories ?? [], after.categories, stableJson),
    items: diffById(prev?.items ?? [], after.items, itemKey),
  };
}

/** Totals stored on the version (`versions/{n}.summary`). */
export function summaryCounts(s: ChangeSummary): {
  added: number;
  changed: number;
  removed: number;
  profileChanged: boolean;
  themeChanged: boolean;
} {
  return {
    added: s.categories.added.length + s.items.added.length,
    changed: s.categories.changed.length + s.items.changed.length,
    removed: s.categories.removed.length + s.items.removed.length,
    profileChanged: s.profileChanged,
    themeChanged: s.themeChanged,
  };
}

/** True when publishing would change nothing customers see. */
export function isEmptySummary(s: ChangeSummary): boolean {
  const c = summaryCounts(s);
  return !s.firstPublish && c.added + c.changed + c.removed === 0 && !c.profileChanged && !c.themeChanged;
}

// ---- validation (FR-066, BR-003, BR-011) -----------------------------------

/**
 * Stable problem codes. The owner app maps each to an `.arb` message and a
 * "Fix" link (`PublishProblemCode` in `features/publishing/domain`).
 */
export const ProblemCode = {
  /** The owner's email is not verified (FR-091). */
  emailNotVerified: "email-not-verified",
  /** No active category with a visible item (BR-003). */
  menuEmpty: "menu-empty",
  /** A required field is empty: `target` + `id` + `field`. */
  missingField: "missing-field",
  /** A field has a value that cannot be published: `target` + `id` + `field`. */
  invalidField: "invalid-field",
  /** More items or categories than the plan allows (BR-011): `details {limit, max, count}`. */
  limitExceeded: "limit-exceeded",
  /** The currency changed after a publish; prices must be confirmed (FR-103). */
  pricesNeedReview: "prices-need-review",
  /** The snapshot does not fit in one document. */
  snapshotTooLarge: "snapshot-too-large",
  /** A premium theme on a plan without premium themes (M10, BR-011). */
  premiumTheme: "premium-theme",
} as const;

export type ProblemCode = (typeof ProblemCode)[keyof typeof ProblemCode];

export interface PublishProblem {
  code: ProblemCode;
  target?: "restaurant" | "category" | "item";
  id?: string;
  field?: string;
  /** Category or item name, so the list reads well without another lookup. */
  name?: string;
  details?: Data;
}

export interface ValidationContext {
  emailVerified: boolean;
  pricesNeedReview: boolean;
  /** The owner ticked "I have checked the prices" in the publish dialog. */
  pricesReviewed: boolean;
  maxItems: number | null;
  maxCategories: number | null;
  planId: string;
  /** The chosen theme is premium (`themes/{id}.premium`, M10). */
  themePremium?: boolean;
  /** The plan allows premium themes (`limits.premiumThemes`, M10). Default true. */
  premiumThemes?: boolean;
}

/** Why a day's opening hours are invalid (ports `OpeningHours.validateDay` from core). */
export type HoursIssue = "format" | "too-many-slots" | "same-time" | "overlap" | "overnight-not-last";

const MAX_SLOTS = 3;

function parseHhMm(t: string): number | null {
  const m = /^([01][0-9]|2[0-3]):([0-5][0-9])$/.exec(t);
  return m ? Number(m[1]) * 60 + Number(m[2]) : null;
}

/**
 * Checks one day's `"HH:mm-HH:mm,…"` string the way the owner app does
 * (the rules only check the format, M03).
 *
 * @param value The day's string; `""` is closed.
 * @return The first issue, or null.
 */
export function validateHoursDay(value: string): HoursIssue | null {
  if (value === "") return null;
  const slots: { open: number; close: number }[] = [];
  for (const part of value.split(",")) {
    const [a, b, ...rest] = part.split("-");
    const open = a === undefined ? null : parseHhMm(a);
    const close = b === undefined ? null : parseHhMm(b);
    if (rest.length > 0 || open === null || close === null) return "format";
    slots.push({ open, close });
  }
  if (slots.length > MAX_SLOTS) return "too-many-slots";
  const allDay = (s: { open: number; close: number }) => s.open === 0 && s.close === 0;
  for (const s of slots) if (s.open === s.close && !allDay(s)) return "same-time";
  if (slots.some(allDay) && slots.length > 1) return "overlap";
  for (let i = 0; i < slots.length - 1; i++) {
    const s = slots[i];
    if (s.close !== 0 && s.close < s.open) return "overnight-not-last";
    const end = s.close <= s.open ? s.close + 1440 : s.close;
    if (end > slots[i + 1].open) return "overlap";
  }
  return null;
}

/**
 * Every reason the draft cannot be published (FR-066), in a stable order:
 * account, then the restaurant, then plan limits, then empty menu, then
 * categories and items in display order.
 *
 * Only public content is checked for required fields: inactive categories
 * and hidden items never reach customers (BR-008).
 *
 * @param input The draft.
 * @param snapshot `buildSnapshot(input)`.
 * @param ctx Account state and plan limits.
 * @return The problems; empty when publishing may go ahead.
 */
export function validateDraft(input: DraftInput, snapshot: MenuSnapshot, ctx: ValidationContext): PublishProblem[] {
  const problems: PublishProblem[] = [];
  const r = input.restaurant;

  if (!ctx.emailVerified) problems.push({ code: ProblemCode.emailNotVerified });

  if (!str(r.name)) problems.push({ code: ProblemCode.missingField, target: "restaurant", field: "name" });
  if (typeof r.currency !== "string" || !/^[A-Z]{3}$/.test(r.currency)) {
    problems.push({ code: ProblemCode.missingField, target: "restaurant", field: "currency" });
  }
  if (!str(r.timezone)) problems.push({ code: ProblemCode.missingField, target: "restaurant", field: "timezone" });
  const hours = r.openingHours;
  if (hours && typeof hours === "object") {
    for (const d of WEEKDAYS) {
      const v = (hours as Data)[d];
      const issue = typeof v === "string" ? validateHoursDay(v) : v === undefined || v === null ? null : "format";
      if (issue) {
        problems.push({
          code: ProblemCode.invalidField,
          target: "restaurant",
          field: `openingHours.${d}`,
          details: { issue },
        });
      }
    }
  }

  if (ctx.pricesNeedReview && !ctx.pricesReviewed) problems.push({ code: ProblemCode.pricesNeedReview });

  // M10 (BR-011): premium themes only on plans that include them.
  if (ctx.themePremium === true && ctx.premiumThemes === false) {
    problems.push({ code: ProblemCode.premiumTheme, details: { themeId: input.restaurant.themeId ?? null, planId: ctx.planId } });
  }

  // BR-011: the same counts the create callables use (non-deleted), except
  // items already hidden over the limit, which never go public (FR-101).
  const liveCategories = input.categories.filter((c) => isLive(c.data) && c.data.hiddenOverLimit !== true).length;
  const liveItems = input.items.filter((i) => isLive(i.data) && i.data.hiddenOverLimit !== true).length;
  if (ctx.maxCategories !== null && liveCategories > ctx.maxCategories) {
    problems.push({
      code: ProblemCode.limitExceeded,
      details: { limit: "categories", max: ctx.maxCategories, count: liveCategories, planId: ctx.planId },
    });
  }
  if (ctx.maxItems !== null && liveItems > ctx.maxItems) {
    problems.push({
      code: ProblemCode.limitExceeded,
      details: { limit: "items", max: ctx.maxItems, count: liveItems, planId: ctx.planId },
    });
  }

  // BR-003: at least one active category containing at least one item.
  if (snapshot.items.length === 0) problems.push({ code: ProblemCode.menuEmpty });

  const categoryIds = new Set(snapshot.categories.map((c) => c.id));
  for (const c of publicCategories(input.categories)) {
    if (!str(c.data.name)) {
      problems.push({ code: ProblemCode.missingField, target: "category", id: c.id, field: "name" });
    }
  }
  for (const i of publicItems(input.items, input.categories)) {
    const d = i.data;
    const name = str(d.name);
    const ref = { target: "item" as const, id: i.id, ...(name ? { name } : {}) };
    if (!categoryIds.has(String(d.categoryId))) continue;
    if (!name) problems.push({ code: ProblemCode.missingField, ...ref, field: "name" });
    if (d.priceMinor === undefined || d.priceMinor === null) {
      problems.push({ code: ProblemCode.missingField, ...ref, field: "priceMinor" });
    } else if (typeof d.priceMinor !== "number" || !Number.isInteger(d.priceMinor) || d.priceMinor < 0) {
      problems.push({ code: ProblemCode.invalidField, ...ref, field: "priceMinor" });
    }
    const labelId = d.dietaryLabelId;
    if (typeof labelId !== "string" || labelId === "") {
      problems.push({ code: ProblemCode.missingField, ...ref, field: "dietaryLabelId" });
    } else if (!input.labels[labelId]) {
      problems.push({ code: ProblemCode.invalidField, ...ref, field: "dietaryLabelId" });
    }
  }

  const bytes = Buffer.byteLength(JSON.stringify(snapshot), "utf8");
  if (bytes > MAX_SNAPSHOT_BYTES) {
    problems.push({ code: ProblemCode.snapshotTooLarge, details: { bytes, max: MAX_SNAPSHOT_BYTES } });
  }
  return problems;
}

// ---- draft source (private; for discard and rollback) ----------------------

/** Root fields restored by discard and rollback (the draft profile and theme). */
export const DRAFT_ROOT_FIELDS = [
  "name",
  "businessType",
  "description",
  "logo",
  "cover",
  "contact",
  "openingHours",
  "visibility",
  "currency",
  "timezone",
  "themeId",
  "themeSettings",
] as const;

export const DRAFT_CATEGORY_FIELDS = ["name", "description", "image", "sequence", "active", "hiddenOverLimit"] as const;

/** `available` is not here: it is live and survives a discard (FR-095). */
export const DRAFT_ITEM_FIELDS = [
  "categoryId",
  "name",
  "description",
  "image",
  "priceMinor",
  "dietaryLabelId",
  "tagIds",
  "featured",
  "sequence",
  "hiddenOverLimit",
] as const;

/**
 * The full draft at publish time, stored in `versions/{n}/private/source`
 * (Functions only). The public snapshot leaves out inactive categories,
 * hidden items and raw image objects, so it cannot rebuild the draft.
 */
export interface DraftSource {
  restaurant: Data;
  categories: DocEntry[];
  items: DocEntry[];
  /** Storage path → URL, reused by the next publish. */
  imageUrls: Record<string, string>;
}

function pick(data: Data, fields: readonly string[]): Data {
  const out: Data = {};
  for (const f of fields) out[f] = data[f] === undefined ? null : data[f];
  return out;
}

/**
 * The draft's non-deleted content, reduced to the fields the owner edits.
 *
 * @param input The draft.
 * @return The source to store with the version.
 */
export function buildDraftSource(input: DraftInput): DraftSource {
  const urls: Record<string, string> = {};
  for (const p of imagePathsOf(input)) if (input.imageUrls[p]) urls[p] = input.imageUrls[p];
  return {
    restaurant: pick(input.restaurant, DRAFT_ROOT_FIELDS),
    categories: input.categories
      .filter((c) => isLive(c.data))
      .sort(compareSequenced)
      .map((c) => ({ id: c.id, data: pick(c.data, DRAFT_CATEGORY_FIELDS) })),
    items: input.items
      .filter((i) => isLive(i.data))
      .sort(compareSequenced)
      .map((i) => ({ id: i.id, data: { ...pick(i.data, DRAFT_ITEM_FIELDS), tagIds: Array.isArray(i.data.tagIds) ? i.data.tagIds : [] } })),
    imageUrls: urls,
  };
}
