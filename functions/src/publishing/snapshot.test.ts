import { formatDayHours, formatPrice } from "../public/format";
import { esc, safeUrl } from "../public/html";
import { renderMenuPage } from "../public/render-menu";
import { DEFAULT_TOKENS, resolveTheme, SEED_THEMES } from "../theme";
import {
  buildDraftSource,
  buildSnapshot,
  diffSnapshots,
  imagePathsOf,
  isEmptySummary,
  localeFor,
  MAX_SNAPSHOT_BYTES,
  stableJson,
  summaryCounts,
  validateDraft,
  validateHoursDay,
  type DocEntry,
  type DraftInput,
  type ValidationContext,
} from "./snapshot";

type Data = Record<string, unknown>;

const ready = (id: string, w = 1200, h = 800) => ({
  path: `restaurants/r/images/${id}/original.jpg`,
  status: "ready",
  contentType: "image/jpeg",
  width: w,
  height: h,
  renditions: {
    w320: `restaurants/r/images/${id}/w320.webp`,
    w640: `restaurants/r/images/${id}/w640.webp`,
    w1280: `restaurants/r/images/${id}/w1280.webp`,
  },
});

const url = (p: string) => `https://img.test/${p}`;

function cat(id: string, sequence: number, extra: Data = {}): DocEntry {
  return { id, data: { name: `Cat ${id}`, description: "", image: null, sequence, active: true, deletedAt: null, ...extra } };
}

function item(id: string, categoryId: string, sequence: number, extra: Data = {}): DocEntry {
  return {
    id,
    data: {
      categoryId,
      name: `Item ${id}`,
      description: "",
      image: null,
      priceMinor: 12900,
      dietaryLabelId: "vegetarian",
      tagIds: [],
      available: true,
      featured: false,
      sequence,
      hiddenOverLimit: false,
      deletedAt: null,
      deletedWith: null,
      ...extra,
    },
  };
}

function draft(extra: Partial<DraftInput> = {}, restaurant: Data = {}): DraftInput {
  const input: DraftInput = {
    restaurant: {
      name: "Spice Garden",
      businessType: "restaurant",
      description: "South Indian classics",
      country: "IN",
      currency: "INR",
      timezone: "Asia/Kolkata",
      contact: {
        phone: "+914423456789",
        email: "hi@spice.test",
        address: "12 Anna Salai",
        city: "Chennai",
        postalCode: "600002",
        website: "https://spice.test",
        social: { instagram: "https://instagram.com/spice" },
      },
      openingHours: { mon: "07:00-11:00,18:00-23:30", tue: "", wed: "", thu: "", fri: "", sat: "", sun: "00:00-00:00" },
      visibility: { phone: true, email: true, address: true, hours: true, social: true },
      themeId: "saffron",
      themeSettings: {},
      publishedVersion: null,
      pricesNeedReview: false,
      ...restaurant,
    },
    categories: [cat("c1", 1000), cat("c2", 2000)],
    items: [item("i1", "c1", 1000), item("i2", "c1", 2000), item("i3", "c2", 1000)],
    labels: {
      "vegetarian": { name: "Vegetarian", icon: "veg", color: "#0F7B0F", sort: 10, retired: false },
      "non-vegetarian": { name: "Non-vegetarian", icon: "nonVeg", color: "#8B2E16", sort: 20, retired: false },
    },
    tags: {
      "spicy": { name: "Spicy", icon: "spicy", color: "#C62828", sort: 10, retired: false },
      "old": { name: "Old tag", icon: null, color: null, sort: 99, retired: true },
    },
    themeTokens: SEED_THEMES.find((t) => t.id === "saffron")!.tokens,
    imageUrls: {},
    ...extra,
  };
  return input;
}

const okCtx: ValidationContext = {
  emailVerified: true,
  pricesNeedReview: false,
  pricesReviewed: false,
  maxItems: 50,
  maxCategories: 10,
  planId: "free",
};

const codes = (input: DraftInput, ctx: Partial<ValidationContext> = {}) =>
  validateDraft(input, buildSnapshot(input), { ...okCtx, ...ctx }).map((p) => p.code);

describe("buildSnapshot", () => {
  it("keeps profile fields, currency, locale and time zone", () => {
    const s = buildSnapshot(draft());
    expect(s.schema).toBe(1);
    expect(s.profile.name).toBe("Spice Garden");
    expect(s.profile.businessType).toBe("restaurant");
    expect(s.profile.description).toBe("South Indian classics");
    expect(s.profile.contact).toEqual({
      phone: "+914423456789",
      email: "hi@spice.test",
      address: "12 Anna Salai",
      city: "Chennai",
      postalCode: "600002",
      website: "https://spice.test",
      social: { instagram: "https://instagram.com/spice" },
    });
    expect(s.profile.openingHours?.mon).toBe("07:00-11:00,18:00-23:30");
    expect(s.currency).toBe("INR");
    expect(s.locale).toBe("en-IN");
    expect(s.timezone).toBe("Asia/Kolkata");
  });

  it("respects visibility: hidden groups are left out, missing flags mean shown", () => {
    const hidden = buildSnapshot(
      draft({}, { visibility: { phone: false, email: false, address: false, hours: false, social: false } }),
    );
    expect(hidden.profile.contact).toEqual({});
    expect(hidden.profile.openingHours).toBeUndefined();

    const partial = buildSnapshot(draft({}, { visibility: { phone: false } }));
    expect(partial.profile.contact.phone).toBeUndefined();
    expect(partial.profile.contact.email).toBe("hi@spice.test");
    expect(partial.profile.openingHours).toBeDefined();

    const none = buildSnapshot(draft({}, { visibility: undefined }));
    expect(none.profile.contact.phone).toBe("+914423456789");
  });

  it("leaves out empty contact values and absent hours", () => {
    const s = buildSnapshot(draft({}, { contact: { city: "Chennai", phone: " " }, openingHours: null, description: "" }));
    expect(s.profile.contact).toEqual({ city: "Chennai" });
    expect(s.profile.openingHours).toBeUndefined();
    expect(s.profile.description).toBeUndefined();
  });

  it("drops inactive and deleted categories and their items", () => {
    const s = buildSnapshot(
      draft({
        categories: [cat("c1", 1000), cat("c2", 2000, { active: false }), cat("c3", 3000, { deletedAt: new Date() })],
        items: [item("i1", "c1", 1000), item("i2", "c2", 1000), item("i3", "c3", 1000)],
      }),
    );
    expect(s.categories.map((c) => c.id)).toEqual(["c1"]);
    expect(s.items.map((i) => i.id)).toEqual(["i1"]);
  });

  it("drops deleted and hidden-over-limit items (BR-008)", () => {
    const s = buildSnapshot(
      draft({
        items: [
          item("i1", "c1", 1000),
          item("i2", "c1", 2000, { deletedAt: new Date() }),
          item("i3", "c1", 3000, { hiddenOverLimit: true }),
          item("i4", "missing", 1000),
        ],
      }),
    );
    expect(s.items.map((i) => i.id)).toEqual(["i1"]);
  });

  it("orders categories and items by sequence, then id", () => {
    const s = buildSnapshot(
      draft({
        categories: [cat("b", 2000), cat("a", 2000), cat("z", 500)],
        items: [item("i9", "a", 10), item("i2", "b", 5), item("i1", "z", 30), item("i0", "z", 30), item("i3", "z", 1)],
      }),
    );
    expect(s.categories.map((c) => c.id)).toEqual(["z", "a", "b"]);
    expect(s.items.map((i) => i.id)).toEqual(["i3", "i0", "i1", "i9", "i2"]);
  });

  it("resolves labels and tags, dropping unknown tag ids and keeping retired ones", () => {
    const s = buildSnapshot(draft({ items: [item("i1", "c1", 1, { tagIds: ["spicy", "ghost", "old", "spicy"] })] }));
    expect(s.items[0].dietaryLabel).toEqual({ id: "vegetarian", name: "Vegetarian", icon: "veg", color: "#0F7B0F" });
    expect(s.items[0].tags.map((t) => t.id)).toEqual(["spicy", "old"]);
  });

  it("keeps public item fields and integer prices", () => {
    const s = buildSnapshot(
      draft({ items: [item("i1", "c1", 7, { priceMinor: 1250, featured: true, available: false, description: "Crisp" })] }),
    );
    expect(s.items[0]).toMatchObject({
      id: "i1",
      categoryId: "c1",
      name: "Item i1",
      description: "Crisp",
      priceMinor: 1250,
      featured: true,
      available: false,
      sequence: 7,
    });
    expect(s.items[0]).not.toHaveProperty("hiddenOverLimit");
    expect(s.items[0]).not.toHaveProperty("deletedAt");
  });

  it("uses rendition URLs for ready images only", () => {
    const logo = ready("logo");
    const imageUrls = Object.fromEntries(Object.values(logo.renditions).map((p) => [p, url(p)]));
    const s = buildSnapshot(
      draft(
        {
          imageUrls,
          items: [
            item("i1", "c1", 1, { image: { path: "x", status: "processing" } }),
            item("i2", "c1", 2, { image: ready("unresolved") }),
          ],
        },
        { logo, cover: { path: "y", status: "rejected", reason: "too-small" } },
      ),
    );
    expect(s.profile.logo).toEqual({
      width: 1200,
      height: 800,
      w320: url(logo.renditions.w320),
      w640: url(logo.renditions.w640),
      w1280: url(logo.renditions.w1280),
    });
    expect(s.profile.cover).toBeUndefined();
    expect(s.items[0].image).toBeUndefined();
    expect(s.items[1].image).toBeUndefined();
  });

  it("lists every rendition path the draft uses", () => {
    const paths = imagePathsOf(draft({ items: [item("i1", "c1", 1, { image: ready("a") })] }, { cover: ready("b") }));
    expect(paths).toHaveLength(6);
  });

  it("copies theme tokens and contrast-fixes the colours", () => {
    const s = buildSnapshot(draft({}, { themeSettings: { background: "#FFFF00", primary: "#FFFF66" } }));
    expect(s.theme.themeId).toBe("saffron");
    expect(s.theme.settings).toEqual({ background: "#FFFF00", primary: "#FFFF66" });
    expect({ ...s.theme.resolved, issues: [] }).toEqual({ ...resolveTheme(s.theme.tokens, s.theme.settings), issues: [] });
    expect(s.theme.resolved).not.toHaveProperty("issues");
    expect(s.theme.resolved.accent).not.toBe("#FFFF66");
  });

  it("uses the default tokens when no theme is chosen", () => {
    const s = buildSnapshot(draft({ themeTokens: { primary: "#000000" } }, { themeId: null }));
    expect(s.theme.themeId).toBeNull();
    expect(s.theme.tokens).toEqual(DEFAULT_TOKENS);
  });

  it("falls back to `en` for an unknown country", () => {
    expect(localeFor("KW")).toBe("en-KW");
    expect(localeFor(undefined)).toBe("en");
  });
});

describe("diffSnapshots", () => {
  const base = buildSnapshot(draft());

  it("marks everything added on the first publish", () => {
    const d = diffSnapshots(null, base);
    expect(d.firstPublish).toBe(true);
    expect(d.categories.added).toHaveLength(2);
    expect(d.items.added.map((i) => i.id)).toEqual(["i1", "i2", "i3"]);
    expect(isEmptySummary(d)).toBe(false);
  });

  it("finds added, changed and removed items and categories by id", () => {
    const next = buildSnapshot(
      draft({
        categories: [cat("c1", 1000, { name: "Starters" }), cat("c3", 3000)],
        items: [item("i1", "c1", 1000, { priceMinor: 13900 }), item("i2", "c1", 2000), item("i4", "c3", 1000)],
      }),
    );
    const d = diffSnapshots(base, next);
    expect(d.categories).toEqual({
      added: [{ id: "c3", name: "Cat c3" }],
      changed: [{ id: "c1", name: "Starters" }],
      removed: [{ id: "c2", name: "Cat c2" }],
    });
    expect(d.items.added.map((i) => i.id)).toEqual(["i4"]);
    expect(d.items.changed.map((i) => i.id)).toEqual(["i1"]);
    expect(d.items.removed.map((i) => i.id)).toEqual(["i3"]);
    expect(summaryCounts(d)).toEqual({ added: 2, changed: 2, removed: 2, profileChanged: false, themeChanged: false });
  });

  it("ignores availability (it is live, FR-095)", () => {
    const next = buildSnapshot(draft({ items: [item("i1", "c1", 1000, { available: false }), item("i2", "c1", 2000), item("i3", "c2", 1000)] }));
    const d = diffSnapshots(base, next);
    expect(isEmptySummary(d)).toBe(true);
  });

  it("reports profile and theme changes", () => {
    const d = diffSnapshots(base, buildSnapshot(draft({}, { description: "New", themeSettings: { mode: "dark" } })));
    expect(d.profileChanged).toBe(true);
    expect(d.themeChanged).toBe(true);
  });

  it("stableJson ignores key order", () => {
    expect(stableJson({ a: 1, b: [1, { d: 2, c: 3 }] })).toBe(stableJson({ b: [1, { c: 3, d: 2 }], a: 1 }));
  });
});

describe("validateDraft", () => {
  it("passes a complete menu", () => {
    expect(codes(draft())).toEqual([]);
  });

  it("blocks an empty menu (BR-003, AC-021)", () => {
    expect(codes(draft({ items: [] }))).toEqual(["menu-empty"]);
    expect(codes(draft({ categories: [cat("c1", 1, { active: false })] }))).toEqual(["menu-empty"]);
    expect(codes(draft({ items: [item("i1", "c1", 1, { hiddenOverLimit: true })] }))).toEqual(["menu-empty"]);
    expect(codes(draft({ categories: [], items: [] }))).toEqual(["menu-empty"]);
  });

  it("reports an unverified email", () => {
    expect(codes(draft(), { emailVerified: false })).toEqual(["email-not-verified"]);
  });

  it("asks for a price review until the owner confirms (FR-103)", () => {
    expect(codes(draft(), { pricesNeedReview: true })).toEqual(["prices-need-review"]);
    expect(codes(draft(), { pricesNeedReview: true, pricesReviewed: true })).toEqual([]);
  });

  it("blocks content over the plan limits (BR-011)", () => {
    const problems = validateDraft(draft(), buildSnapshot(draft()), { ...okCtx, maxItems: 2, maxCategories: 1 });
    expect(problems).toEqual([
      { code: "limit-exceeded", details: { limit: "categories", max: 1, count: 2, planId: "free" } },
      { code: "limit-exceeded", details: { limit: "items", max: 2, count: 3, planId: "free" } },
    ]);
    expect(codes(draft(), { maxItems: null, maxCategories: null })).toEqual([]);
  });

  it("does not count hidden-over-limit or deleted items against the limit", () => {
    const input = draft({
      items: [
        item("i1", "c1", 1),
        item("i2", "c1", 2, { hiddenOverLimit: true }),
        item("i3", "c1", 3, { deletedAt: new Date() }),
      ],
    });
    expect(codes(input, { maxItems: 1 })).toEqual([]);
  });

  it("lists missing and invalid fields of public content with ids", () => {
    const input = draft(
      {
        categories: [cat("c1", 1, { name: " " }), cat("c2", 2, { active: false, name: "" })],
        items: [
          item("i1", "c1", 1, { name: "" }),
          item("i2", "c1", 2, { priceMinor: null }),
          item("i3", "c1", 3, { priceMinor: 12.5 }),
          item("i4", "c1", 4, { dietaryLabelId: "" }),
          item("i5", "c1", 5, { dietaryLabelId: "gone" }),
          item("i6", "c2", 1, { name: "" }),
        ],
      },
      { name: "", currency: "inr", timezone: "" },
    );
    const problems = validateDraft(input, buildSnapshot(input), okCtx);
    expect(problems).toEqual([
      { code: "missing-field", target: "restaurant", field: "name" },
      { code: "missing-field", target: "restaurant", field: "currency" },
      { code: "missing-field", target: "restaurant", field: "timezone" },
      { code: "missing-field", target: "category", id: "c1", field: "name" },
      { code: "missing-field", target: "item", id: "i1", field: "name" },
      { code: "missing-field", target: "item", id: "i2", name: "Item i2", field: "priceMinor" },
      { code: "invalid-field", target: "item", id: "i3", name: "Item i3", field: "priceMinor" },
      { code: "missing-field", target: "item", id: "i4", name: "Item i4", field: "dietaryLabelId" },
      { code: "invalid-field", target: "item", id: "i5", name: "Item i5", field: "dietaryLabelId" },
    ]);
  });

  it("checks opening hours order and overlaps (M03 left these to M06)", () => {
    const input = draft({}, { openingHours: { mon: "18:00-23:00,07:00-11:00", tue: "09:00-09:00", wed: "bad" } });
    const problems = validateDraft(input, buildSnapshot(input), okCtx);
    expect(problems).toEqual([
      { code: "invalid-field", target: "restaurant", field: "openingHours.mon", details: { issue: "overlap" } },
      { code: "invalid-field", target: "restaurant", field: "openingHours.tue", details: { issue: "same-time" } },
      { code: "invalid-field", target: "restaurant", field: "openingHours.wed", details: { issue: "format" } },
    ]);
  });

  it("validates one day like the owner app", () => {
    expect(validateHoursDay("")).toBeNull();
    expect(validateHoursDay("00:00-00:00")).toBeNull();
    expect(validateHoursDay("07:00-11:00,18:00-02:00")).toBeNull();
    expect(validateHoursDay("18:00-02:00,03:00-05:00")).toBe("overnight-not-last");
    expect(validateHoursDay("07:00-08:00,09:00-10:00,11:00-12:00,13:00-14:00")).toBe("too-many-slots");
    expect(validateHoursDay("00:00-00:00,07:00-08:00")).toBe("overlap");
    expect(validateHoursDay("07:00-12:00,11:00-14:00")).toBe("overlap");
    expect(validateHoursDay("7:00-12:00")).toBe("format");
  });

  it("blocks a snapshot that would not fit in one document", () => {
    const big = "x".repeat(1000);
    const items = Array.from({ length: MAX_SNAPSHOT_BYTES / 900 }, (_, i) => item(`i${i}`, "c1", i, { description: big }));
    expect(codes(draft({ items }), { maxItems: null })).toEqual(["snapshot-too-large"]);
  });
});

describe("buildDraftSource", () => {
  it("keeps every non-deleted category and item, without availability", () => {
    const input = draft({
      categories: [cat("c1", 1), cat("c2", 2, { active: false }), cat("c3", 3, { deletedAt: new Date() })],
      items: [item("i1", "c1", 1), item("i2", "c2", 1, { hiddenOverLimit: true }), item("i3", "c1", 2, { deletedAt: new Date() })],
    });
    const src = buildDraftSource(input);
    expect(src.categories.map((c) => c.id)).toEqual(["c1", "c2"]);
    expect(src.items.map((i) => i.id)).toEqual(["i1", "i2"]);
    expect(src.items[1].data.hiddenOverLimit).toBe(true);
    expect(src.items[0].data).not.toHaveProperty("available");
    expect(src.restaurant).toHaveProperty("themeSettings");
    expect(src.restaurant).not.toHaveProperty("publishedVersion");
  });
});

describe("format", () => {
  it("formats minor units without floats, with the currency's decimals", () => {
    expect(formatPrice(12900, "INR", "en-IN")).toBe("₹129.00");
    expect(formatPrice(12345678, "INR", "en-IN")).toBe("₹1,23,456.78");
    expect(formatPrice(1250, "KWD", "en-KW")).toMatch(/1\.250/);
    expect(formatPrice(5, "KWD", "en-KW")).toMatch(/0\.005/);
    expect(formatPrice(999999999, "USD", "en-US")).toBe("$9,999,999.99");
  });

  it("formats a day's hours", () => {
    const t = { closed: "Closed", allDay: "Open 24 hours" };
    expect(formatDayHours("", t)).toBe("Closed");
    expect(formatDayHours("00:00-00:00", t)).toBe("Open 24 hours");
    expect(formatDayHours("07:00-11:00,18:00-23:30", t)).toBe("07:00–11:00, 18:00–23:30");
  });
});

describe("renderMenuPage", () => {
  it("renders the draft with noindex, a preview banner and escaped values", () => {
    const input = draft({ items: [item("i1", "c1", 1, { name: "<script>alert(1)</script>", featured: true })] });
    const html = renderMenuPage(buildSnapshot(input), { draft: true });
    expect(html).toContain("<meta name=\"robots\" content=\"noindex,nofollow\">");
    expect(html).toContain("Preview – this is your unpublished draft");
    expect(html).not.toContain("<script>alert(1)</script>");
    expect(html).toContain("&lt;script&gt;alert(1)&lt;/script&gt;");
    expect(html).toContain("₹129.00");
    expect(html).toContain("--es-accent:");
    expect(html).toContain("Featured");
  });

  it("shows sold-out items with a badge and the availability overlay wins", () => {
    const s = buildSnapshot(draft());
    const html = renderMenuPage(s, { availability: { i1: false } });
    expect(html).not.toContain("noindex");
    expect(html.match(/aria-disabled="true"/g)).toHaveLength(1);
    expect(html).toContain("Sold out");
  });

  it("uses srcset with the three renditions", () => {
    const img = ready("a");
    const imageUrls = Object.fromEntries(Object.values(img.renditions).map((p) => [p, url(p)]));
    const html = renderMenuPage(buildSnapshot(draft({ imageUrls, items: [item("i1", "c1", 1, { image: img })] })));
    expect(html).toContain(`${url(img.renditions.w320)} 320w`);
    expect(html).toContain("loading=\"lazy\"");
  });

  it("only links https URLs", () => {
    expect(safeUrl("javascript:alert(1)")).toBeNull();
    expect(safeUrl("https://ok.test/a")).toBe("https://ok.test/a");
    expect(esc("\"'&")).toBe("&quot;&#39;&amp;");
  });
});
