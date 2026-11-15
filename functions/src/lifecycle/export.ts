/**
 * `exportMenu` (M12, FR-105): the owner's menu as JSON and CSV, built from
 * the current draft (every live category and item, active or not, hidden
 * over a limit or not). Prices stay integer minor units next to the
 * ISO 4217 currency (BR-019); the CSV adds the decimal amount for people.
 *
 * The files are returned in the callable's result (a 500-item menu is well
 * under the 10 MB callable limit) and saved by the app: a browser download
 * on web, the share sheet on mobile. Nothing is written to Storage, so no
 * signed URL or service-account signing is needed.
 */
import type { Firestore } from "firebase-admin/firestore";
import { z } from "zod";

import { writeAudit } from "../lib/audit";
import { assertOwner, type CallerAuth , assertSignedIn } from "../lib/auth";
import { parseInput } from "../lib/validation";
import { majorAmount } from "../public/format";
import { compareSequenced, type DocEntry } from "../publishing/snapshot";

type Data = Record<string, unknown>;

export const exportSchema = z.object({ restaurantId: z.string().min(1).max(128).regex(/^[A-Za-z0-9_-]+$/) }).strict();

export const EXPORT_SCHEMA_VERSION = 1;

export interface MenuExport {
  schema: number;
  exportedAt: string;
  restaurant: { id: string; name: string; slug: string; currency: string; country: string; timezone: string };
  categories: Array<{ id: string; name: string; description: string; active: boolean; hiddenOverLimit: boolean; sequence: number }>;
  items: Array<{
    id: string;
    categoryId: string;
    categoryName: string;
    name: string;
    description: string;
    priceMinor: number | null;
    currency: string;
    dietaryLabel: string | null;
    tags: string[];
    available: boolean;
    featured: boolean;
    hiddenOverLimit: boolean;
    sequence: number;
  }>;
}

const str = (v: unknown) => (typeof v === "string" ? v : "");
const isLive = (d: Data) => d.deletedAt === null || d.deletedAt === undefined;

/** Builds the export from the draft documents (pure). */
export function buildMenuExport(
  restaurantId: string,
  r: Data,
  categories: DocEntry[],
  items: DocEntry[],
  labelNames: Record<string, string>,
  tagNames: Record<string, string>,
  now: Date,
): MenuExport {
  const cats = categories.filter((c) => isLive(c.data)).sort(compareSequenced);
  const catOrder = new Map(cats.map((c, i) => [c.id, i]));
  const catName = new Map(cats.map((c) => [c.id, str(c.data.name)]));
  const currency = str(r.currency);
  return {
    schema: EXPORT_SCHEMA_VERSION,
    exportedAt: now.toISOString(),
    restaurant: { id: restaurantId, name: str(r.name), slug: str(r.slug), currency, country: str(r.country), timezone: str(r.timezone) },
    categories: cats.map((c) => ({
      id: c.id,
      name: str(c.data.name),
      description: str(c.data.description),
      active: c.data.active !== false,
      hiddenOverLimit: c.data.hiddenOverLimit === true,
      sequence: typeof c.data.sequence === "number" ? c.data.sequence : 0,
    })),
    items: items
      .filter((i) => isLive(i.data) && catOrder.has(str(i.data.categoryId)))
      .sort((a, b) => catOrder.get(str(a.data.categoryId))! - catOrder.get(str(b.data.categoryId))! || compareSequenced(a, b))
      .map((i) => ({
        id: i.id,
        categoryId: str(i.data.categoryId),
        categoryName: catName.get(str(i.data.categoryId)) ?? "",
        name: str(i.data.name),
        description: str(i.data.description),
        priceMinor: typeof i.data.priceMinor === "number" ? i.data.priceMinor : null,
        currency,
        dietaryLabel: typeof i.data.dietaryLabelId === "string" ? labelNames[i.data.dietaryLabelId] ?? i.data.dietaryLabelId : null,
        tags: (Array.isArray(i.data.tagIds) ? i.data.tagIds : []).filter((t): t is string => typeof t === "string").map((t) => tagNames[t] ?? t),
        available: i.data.available !== false,
        featured: i.data.featured === true,
        hiddenOverLimit: i.data.hiddenOverLimit === true,
        sequence: typeof i.data.sequence === "number" ? i.data.sequence : 0,
      })),
  };
}

/** RFC 4180 field: quoted when it holds a comma, quote or line break; formula-like starts neutralised. */
export function csvField(v: unknown): string {
  let s = v === null || v === undefined ? "" : String(v);
  // Spreadsheet formula injection (=, +, -, @ at the start).
  if (/^[=+\-@]/.test(s)) s = `'${s}`;
  return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, "\"\"")}"` : s;
}

/** Byte-order mark, so spreadsheets read the CSV as UTF-8. */
const BOM = String.fromCharCode(0xfeff);

export const CSV_HEADER = ["category", "item", "description", "price_minor", "price", "currency", "dietary_label", "tags", "available", "featured", "hidden_over_limit"];

/** The export as CSV, one row per item, UTF-8 with a BOM for spreadsheets. */
export function menuExportCsv(e: MenuExport): string {
  const rows = [CSV_HEADER.join(",")];
  for (const i of e.items) {
    rows.push(
      [
        i.categoryName,
        i.name,
        i.description,
        i.priceMinor ?? "",
        i.priceMinor === null ? "" : majorAmount(i.priceMinor, i.currency),
        i.currency,
        i.dietaryLabel ?? "",
        i.tags.join("; "),
        i.available ? "yes" : "no",
        i.featured ? "yes" : "no",
        i.hiddenOverLimit ? "yes" : "no",
      ]
        .map(csvField)
        .join(","),
    );
  }
  return `${BOM}${rows.join("\r\n")}\r\n`;
}

/** Callable `exportMenu` (FR-105): `{fileBase, json, csv}`. Allowed while active or suspended. */
export async function exportMenu(
  db: Firestore,
  caller: CallerAuth | undefined | null,
  data: unknown,
  deps: { now?: () => Date } = {},
): Promise<{ fileBase: string; json: string; csv: string; items: number; categories: number }> {
  assertSignedIn(caller); // before input checks: anonymous callers learn nothing (M13)
  const input = parseInput(exportSchema, data);
  const owner = await assertOwner(caller, input.restaurantId, { db, allowedStatuses: ["active", "suspended"] });
  const root = db.doc(`restaurants/${input.restaurantId}`);
  const [cats, items, labels, tags] = await Promise.all([
    root.collection("categories").get(),
    root.collection("items").get(),
    db.collection("dietaryLabels").get(),
    db.collection("itemTags").get(),
  ]);
  const now = (deps.now ?? (() => new Date()))();
  const e = buildMenuExport(
    input.restaurantId,
    owner.restaurant,
    cats.docs.map((d) => ({ id: d.id, data: d.data() })),
    items.docs.map((d) => ({ id: d.id, data: d.data() })),
    Object.fromEntries(labels.docs.map((d) => [d.id, str(d.get("name"))])),
    Object.fromEntries(tags.docs.map((d) => [d.id, str(d.get("name"))])),
    now,
  );
  await writeAudit(
    {
      actorUid: owner.uid,
      actorRole: "owner",
      action: "menu.export",
      restaurantId: input.restaurantId,
      target: `restaurants/${input.restaurantId}`,
      details: { items: e.items.length, categories: e.categories.length },
    },
    { db: db as never },
  );
  const slug = (e.restaurant.slug || "menu").replace(/[^a-z0-9-]/g, "");
  return {
    fileBase: `${slug}-menu-${now.toISOString().slice(0, 10)}`,
    json: JSON.stringify(e, null, 2),
    csv: menuExportCsv(e),
    items: e.items.length,
    categories: e.categories.length,
  };
}
