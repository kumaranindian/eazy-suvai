import { sameName } from "./deletion";
import { buildMenuExport, csvField, menuExportCsv } from "./export";
import { anonymisedAuditPatch, pseudonym, referencedImageFolders } from "./purge";

describe("menu export (FR-105)", () => {
  const cat = (id: string, sequence: number, extra = {}) => ({ id, data: { name: `Cat ${id}`, sequence, active: true, deletedAt: null, ...extra } });
  const item = (id: string, categoryId: string, sequence: number, extra = {}) => ({
    id,
    data: { categoryId, name: `Item ${id}`, description: "", priceMinor: 12900, dietaryLabelId: "vegetarian", tagIds: ["spicy"], available: true, featured: false, sequence, deletedAt: null, ...extra },
  });
  const e = buildMenuExport(
    "r1",
    { name: "Spice Garden", slug: "spice-garden", currency: "KWD", country: "KW", timezone: "Asia/Kuwait" },
    [cat("c2", 2000), cat("c1", 1000), cat("cx", 500, { deletedAt: new Date() })],
    [item("b", "c1", 2000), item("a", "c1", 1000, { priceMinor: 1250 }), item("z", "c2", 1, { hiddenOverLimit: true }), item("gone", "c1", 3000, { deletedAt: new Date() }), item("orphan", "cx", 1)],
    { vegetarian: "Vegetarian" },
    { spicy: "Spicy" },
    new Date("2026-11-15T10:00:00Z"),
  );

  it("has every live category and item in display order, prices in minor units with the currency", () => {
    expect(e.categories.map((c) => c.id)).toEqual(["c1", "c2"]);
    expect(e.items.map((i) => i.id)).toEqual(["a", "b", "z"]);
    expect(e.items[0]).toMatchObject({ priceMinor: 1250, currency: "KWD", dietaryLabel: "Vegetarian", tags: ["Spicy"], categoryName: "Cat c1" });
    expect(e.items[2].hiddenOverLimit).toBe(true);
  });

  it("writes CSV with exact decimals, quoting and no formula injection", () => {
    const csv = menuExportCsv(e);
    expect(csv.charCodeAt(0)).toBe(0xfeff);
    const lines = csv.slice(1).trim().split("\r\n");
    expect(lines[0]).toBe("category,item,description,price_minor,price,currency,dietary_label,tags,available,featured,hidden_over_limit");
    expect(lines[1]).toBe("Cat c1,Item a,,1250,1.250,KWD,Vegetarian,Spicy,yes,no,no");
    expect(csvField("a, \"b\"\nc")).toBe("\"a, \"\"b\"\"\nc\"");
    expect(csvField("=HYPERLINK(1)")).toBe("'=HYPERLINK(1)");
    expect(csvField(null)).toBe("");
  });
});

describe("deletion confirmation", () => {
  it("needs the restaurant's name, ignoring case and spacing", () => {
    expect(sameName("  spice   GARDEN ", "Spice Garden")).toBe(true);
    expect(sameName("Spice", "Spice Garden")).toBe(false);
    expect(sameName("", "")).toBe(false);
  });
});

describe("audit anonymisation (§7.7)", () => {
  it("pseudonymises the owner and drops personal fields, keeping the facts", () => {
    const patch = anonymisedAuditPatch(
      { actorUid: "u1", actorRole: "owner", action: "restaurant.changeSlug", details: { from: "a", to: "b", ownerEmail: "x@y.com", mobile: "+91" } },
      "u1",
    )!;
    expect(patch.actorUid).toBe(pseudonym("u1"));
    expect(patch.details).toEqual({ from: "a", to: "b" });
    expect(pseudonym("u1")).toMatch(/^anon:[0-9a-f]{16}$/);
    expect(anonymisedAuditPatch({ actorUid: "admin1", details: { version: 3 } }, "u1")).toBeNull();
  });
});

describe("referenced image folders (M02)", () => {
  it("finds paths and token URLs anywhere in a document", () => {
    const used = referencedImageFolders({
      logo: { path: "restaurants/r1/images/abc/original.png", renditions: { w320: "restaurants/r1/images/abc/w320.webp" } },
      snapshot: { items: [{ image: { w640: "https://firebasestorage.googleapis.com/v0/b/x/o/restaurants%2Fr1%2Fimages%2Fdef%2Fw640.webp?alt=media" } }] },
      other: 3,
    });
    expect([...used].sort()).toEqual(["restaurants/r1/images/abc/", "restaurants/r1/images/def/"]);
  });
});
