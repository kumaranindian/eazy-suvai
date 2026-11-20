/**
 * Admin editors for platform data (M11, FR-059, FR-076, FR-077, FR-104):
 * plans, dietary labels, item tags, themes, platform settings and the
 * announcement. Every change is validated and audit-logged (BR-014).
 * Labels, tags and themes are retired, never deleted (FR-104).
 */
import { FieldValue, type Firestore } from "firebase-admin/firestore";
import { z } from "zod";

import { writeAudit } from "../lib/audit";
import { assertAdmin, type CallerAuth } from "../lib/auth";
import { appError } from "../lib/errors";
import { parseInput } from "../lib/validation";
import { LIVE_IDLE_MINUTES, LIVE_MAX_MINUTES, liveLimitsOf } from "../public/live-limits";
import { syncPlanFeatures } from "../subscriptions/daily";
import { resolveTheme, parseThemeTokens } from "../theme";

type Data = Record<string, unknown>;

const docId = z.string().regex(/^[a-z0-9][a-z0-9-]{0,62}$/, "lower-case letters, digits and dashes");
const hex = z.string().regex(/^#[0-9A-Fa-f]{6}$/).transform((s) => s.toUpperCase());
const reason = z.string().trim().max(1000).optional();

async function audit(db: Firestore, uid: string, action: string, target: string, details: Data, why?: string): Promise<void> {
  await writeAudit(
    { actorUid: uid, actorRole: "platformAdmin", action, target, details, ...(why ? { reason: why } : {}) },
    { db: db as never },
  );
}

const iso = (v: unknown) => (v && typeof (v as { toDate?: unknown }).toDate === "function" ? (v as { toDate(): Date }).toDate().toISOString() : null);

// ---- plans ------------------------------------------------------------------

const limit = z.number().int().min(-1).max(100_000).nullable();
const pricePair = z.object({ monthly: z.number().int().min(0).max(1e12).nullable().optional(), annual: z.number().int().min(0).max(1e12).nullable().optional() }).strict();

export const upsertPlanSchema = z
  .object({
    id: docId,
    name: z.string().trim().min(1).max(60),
    isFree: z.boolean(),
    active: z.boolean().default(true),
    sort: z.number().int().min(0).max(1000).default(0),
    billing: z.array(z.enum(["monthly", "annual"])).max(2).default([]),
    prices: z.record(z.string().regex(/^[A-Z]{3}$/), pricePair).default({}),
    limits: z
      .object({
        maxItems: limit,
        maxCategories: limit,
        maxBranches: z.number().int().min(1).max(1000),
        premiumThemes: z.boolean(),
        defaultThemeId: docId,
        analyticsDays: z.number().int().min(1).max(3660),
        qrLogo: z.boolean(),
        removeBranding: z.boolean(),
      })
      .strict(),
    /** FR-077: copy the new flags to the plan's current subscribers now. */
    applyToSubscribers: z.boolean().default(false),
    reason,
  })
  .strict();

/** Callable `upsertPlan` (FR-076, FR-077). */
export async function upsertPlan(db: Firestore, caller: CallerAuth | undefined | null, data: unknown): Promise<{ id: string; applied: number }> {
  const admin = assertAdmin(caller);
  const input = parseInput(upsertPlanSchema, data);
  if (input.id === "free" && !input.isFree) throw appError("invalid-input", "The Free plan must stay free (FR-079).", { field: "isFree" });
  const theme = await db.doc(`themes/${input.limits.defaultThemeId}`).get();
  if (!theme.exists || theme.get("premium") === true) {
    throw appError("invalid-input", "The default theme must be an existing standard theme.", { field: "limits.defaultThemeId" });
  }
  const { applyToSubscribers, reason: why, id, ...plan } = input;
  const ref = db.doc(`plans/${id}`);
  const before = (await ref.get()).data();
  await ref.set({ ...plan, updatedAt: FieldValue.serverTimestamp(), updatedBy: admin.uid });
  let applied = 0;
  if (applyToSubscribers) {
    const subs = await db.collection("restaurants").where("planId", "==", id).select().get();
    for (const d of subs.docs) {
      await syncPlanFeatures(db, d.id);
      applied++;
    }
  }
  await audit(db, admin.uid, before ? "plan.update" : "plan.create", `plans/${id}`, { limits: plan.limits, prices: plan.prices, active: plan.active, applied }, why);
  return { id, applied };
}

// ---- labels and tags (FR-023, FR-033, FR-104) --------------------------------

/** Icon keys `MenuLabelIcon` (core) draws. */
export const LABEL_ICONS = ["veg", "nonVeg", "vegan", "egg", "spicy", "bestseller", "chefsSpecial", "new"] as const;

export const upsertLabelSchema = z
  .object({
    kind: z.enum(["label", "tag"]),
    id: docId,
    name: z.string().trim().min(1).max(40),
    icon: z.enum(LABEL_ICONS),
    color: hex,
    sort: z.number().int().min(0).max(10_000),
    retired: z.boolean().default(false),
    reason,
  })
  .strict();

/** Callable `upsertLabel` (dietary labels and item tags; retire instead of delete). */
export async function upsertLabel(db: Firestore, caller: CallerAuth | undefined | null, data: unknown): Promise<{ id: string }> {
  const admin = assertAdmin(caller);
  const input = parseInput(upsertLabelSchema, data);
  const col = input.kind === "label" ? "dietaryLabels" : "itemTags";
  const ref = db.doc(`${col}/${input.id}`);
  const before = await ref.get();
  await ref.set({ name: input.name, icon: input.icon, color: input.color, sort: input.sort, retired: input.retired, updatedAt: FieldValue.serverTimestamp() });
  const verb = !before.exists ? "create" : input.retired && before.get("retired") !== true ? "retire" : "update";
  await audit(db, admin.uid, `${input.kind}.${verb}`, `${col}/${input.id}`, { name: input.name, icon: input.icon, color: input.color, sort: input.sort, retired: input.retired }, input.reason);
  return { id: input.id };
}

// ---- themes (FR-056, FR-059, FR-060) -----------------------------------------

export const upsertThemeSchema = z
  .object({
    id: docId,
    name: z.string().trim().min(1).max(40),
    premium: z.boolean(),
    sort: z.number().int().min(0).max(10_000),
    retired: z.boolean().default(false),
    tokens: z
      .object({
        primary: hex,
        secondary: hex,
        background: hex,
        surface: hex,
        text: hex,
        font: z.string().regex(/^[A-Za-z][A-Za-z ]{0,39}$/),
        layout: z.enum(["list", "grid"]),
        cardLayout: z.enum(["compact", "image-top", "image-left"]),
        mode: z.enum(["light", "dark"]),
      })
      .strict(),
    /** Save even though text colours need the automatic contrast fix. */
    acceptContrastFixes: z.boolean().default(false),
    reason,
  })
  .strict();

/** Callable `upsertTheme` (FR-059): refuses themes whose text fails AA unless accepted. */
export async function upsertTheme(db: Firestore, caller: CallerAuth | undefined | null, data: unknown): Promise<{ id: string; issues: unknown[] }> {
  const admin = assertAdmin(caller);
  const input = parseInput(upsertThemeSchema, data);
  const tokens = parseThemeTokens(input.tokens);
  const issues = resolveTheme(tokens, {}).issues;
  if (issues.length > 0 && !input.acceptContrastFixes) {
    throw appError("invalid-input", "Some text colours fail WCAG AA contrast.", { field: "tokens", issues });
  }
  const ref = db.doc(`themes/${input.id}`);
  const before = await ref.get();
  await ref.set({ name: input.name, premium: input.premium, sort: input.sort, retired: input.retired, tokens, updatedAt: FieldValue.serverTimestamp() });
  const verb = !before.exists ? "create" : input.retired && before.get("retired") !== true ? "retire" : "update";
  await audit(db, admin.uid, `theme.${verb}`, `themes/${input.id}`, { name: input.name, premium: input.premium, tokens, issues: issues.length }, input.reason);
  return { id: input.id, issues };
}

// ---- platform settings and announcement -------------------------------------

export const platformConfigSchema = z
  .object({
    reservedSlugs: z.array(z.string().regex(/^[a-z0-9-]{1,60}$/)).max(1000).optional(),
    graceDays: z.number().int().min(0).max(30).optional(),
    fonts: z.array(z.string().regex(/^[A-Za-z][A-Za-z ]{0,39}$/)).min(1).max(100).optional(),
    currencies: z.record(z.string().regex(/^[A-Z]{3}$/), z.number().int().min(0).max(3)).optional(),
    supportEmail: z.string().email().max(200).optional(),
    /** Open menu pages: stop checking for changes after this idle time / this long after opening. */
    liveIdleMinutes: z.number().int().min(LIVE_IDLE_MINUTES.min).max(LIVE_IDLE_MINUTES.max).optional(),
    liveMaxMinutes: z.number().int().min(LIVE_MAX_MINUTES.min).max(LIVE_MAX_MINUTES.max).optional(),
    reason,
  })
  .strict();

/**
 * Callable `updatePlatformConfig`: reserved slugs, grace days (0–30, FR-100),
 * fonts, currencies, support email, and the open menu page's live-check
 * limits (idle and per-scan minutes).
 */
export async function updatePlatformConfig(db: Firestore, caller: CallerAuth | undefined | null, data: unknown): Promise<{ ok: true }> {
  const admin = assertAdmin(caller);
  const { reason: why, ...patch } = parseInput(platformConfigSchema, data);
  if (Object.keys(patch).length === 0) throw appError("invalid-input", "Nothing to change.");
  if (patch.reservedSlugs) patch.reservedSlugs = [...new Set(patch.reservedSlugs)].sort();
  await db.doc("config/platform").set({ ...patch, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  await audit(db, admin.uid, "platform.updateConfig", "config/platform", { fields: Object.keys(patch), ...patch }, why);
  return { ok: true };
}

export const announcementSchema = z
  .object({
    text: z.string().trim().max(300),
    level: z.enum(["info", "warning"]).default("info"),
    active: z.boolean(),
    /** Hidden after this date (ISO), optional. */
    until: z.string().datetime({ offset: true }).optional(),
  })
  .strict();

/** Callable `setAnnouncement`: the banner owners see (`config/platform.announcement`). */
export async function setAnnouncement(db: Firestore, caller: CallerAuth | undefined | null, data: unknown): Promise<{ ok: true }> {
  const admin = assertAdmin(caller);
  const input = parseInput(announcementSchema, data);
  if (input.active && input.text === "") throw appError("invalid-input", "Write the announcement text.", { field: "text" });
  await db.doc("config/platform").set(
    { announcement: { text: input.text, level: input.level, active: input.active, until: input.until ?? null, updatedAt: FieldValue.serverTimestamp() } },
    { merge: true },
  );
  await audit(db, admin.uid, "platform.announcement", "config/platform", { text: input.text, level: input.level, active: input.active, until: input.until ?? null });
  return { ok: true };
}

// ---- reads for the admin screens --------------------------------------------

export const catalogSchema = z.object({ kind: z.enum(["plans", "labels", "tags", "themes", "config"]) }).strict();

/**
 * Callable `adminListCatalog`: plans, labels, tags, themes or the platform
 * config for the editors (admin reads go through callables, M01).
 */
export async function adminListCatalog(db: Firestore, caller: CallerAuth | undefined | null, data: unknown): Promise<{ entries: Data[] } | { config: Data }> {
  assertAdmin(caller);
  const { kind } = parseInput(catalogSchema, data);
  if (kind === "config") {
    const c = (await db.doc("config/platform").get()).data() ?? {};
    const a = (c.announcement ?? null) as Data | null;
    const limits = liveLimitsOf(c);
    return {
      config: {
        reservedSlugs: c.reservedSlugs ?? null,
        graceDays: typeof c.graceDays === "number" ? c.graceDays : 14,
        fonts: c.fonts ?? [],
        currencies: c.currencies ?? {},
        supportEmail: c.supportEmail ?? null,
        liveIdleMinutes: limits.idleMinutes,
        liveMaxMinutes: limits.maxMinutes,
        announcement: a ? { ...a, updatedAt: iso(a.updatedAt) } : null,
      },
    };
  }
  const col = { plans: "plans", labels: "dietaryLabels", tags: "itemTags", themes: "themes" }[kind];
  const snap = await db.collection(col).get();
  const entries = snap.docs
    .map((d) => {
      const x = d.data();
      return { id: d.id, ...x, updatedAt: iso(x.updatedAt) };
    })
    .sort((a, b) => Number((a as Data).sort ?? 0) - Number((b as Data).sort ?? 0) || a.id.localeCompare(b.id));
  return { entries };
}
