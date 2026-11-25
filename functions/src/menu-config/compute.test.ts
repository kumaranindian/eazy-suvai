import {
  checkItemTags,
  computeMenuConfig,
  effectiveCapabilities,
  parseBusinessType,
  parseCapability,
  parseTagGroup,
  restaurantFeatureFields,
  visibleTagIds,
} from "./compute";
import { BUSINESS_TYPE_DEFS, CAPABILITIES, TAG_GROUPS } from "./seed-data";
import { SINGLE_SLOTS, type CapabilityFlags, type CustomTag, type MenuConfig } from "./types";

const typeOf = (id: string) => BUSINESS_TYPE_DEFS.find((t) => t.id === id) ?? null;
const caps = Object.fromEntries(CAPABILITIES.map((c) => [c.id, c]));
const groups = Object.fromEntries(TAG_GROUPS.map((g) => [g.id, g]));

function config(
  typeId: string | null,
  answers: CapabilityFlags = {},
  more: { disabled?: string[]; custom?: CustomTag[]; plan?: { customTags: boolean; maxCustomTags: number } } = {},
): MenuConfig {
  return computeMenuConfig({
    type: typeId === null ? null : typeOf(typeId),
    capabilities: caps,
    tagGroups: groups,
    restaurant: {
      businessType: typeId,
      capabilities: answers,
      disabledTagGroupIds: more.disabled ?? [],
      customTags: more.custom ?? [],
    },
    plan: more.plan ?? { customTags: false, maxCustomTags: 0 },
  });
}

const groupIds = (c: MenuConfig) => c.tagGroups.map((g) => g.id);
const allTagIds = (c: MenuConfig) => c.tagGroups.flatMap((g) => g.tags.map((t) => t.id));

describe("seed data", () => {
  it("has unique tag ids across all groups (items store bare ids)", () => {
    const ids = TAG_GROUPS.flatMap((g) => g.tags.map((t) => t.id));
    expect(new Set(ids).size).toBe(ids.length);
  });

  it("keeps the M04 label and tag ids (no item rewrite, D2)", () => {
    const ids = TAG_GROUPS.flatMap((g) => g.tags.map((t) => t.id));
    for (const id of ["vegetarian", "non-vegetarian", "vegan", "contains-egg", "spicy", "bestseller", "chefs-special", "new"]) {
      expect(ids).toContain(id);
    }
  });

  it("keeps the ten M01 business type ids (D3)", () => {
    const ids = BUSINESS_TYPE_DEFS.map((t) => t.id);
    for (const id of ["restaurant", "cafe", "bakery", "cloudKitchen", "sweetShop", "juiceBar", "foodTruck", "bar", "hotel", "other"]) {
      expect(ids).toContain(id);
    }
  });

  it("references only existing groups, tags and capabilities", () => {
    const tagIds = new Set(TAG_GROUPS.flatMap((g) => g.tags.map((t) => t.id)));
    for (const t of BUSINESS_TYPE_DEFS) {
      for (const g of t.tagGroupIds) expect(groups[g]).toBeDefined();
      for (const c of Object.keys(t.defaultCapabilities)) expect(caps[c]).toBeDefined();
      expect(new Set(t.defaultCategories.map((c) => c.key)).size).toBe(t.defaultCategories.length);
    }
    for (const c of CAPABILITIES) {
      for (const g of [...c.addTagGroupIds, ...c.hideTagGroupIds]) expect(groups[g]).toBeDefined();
      for (const id of c.hideTagIds) expect(tagIds.has(id)).toBe(true);
    }
    for (const g of TAG_GROUPS) for (const s of g.exclusive) for (const id of s.ids) expect(tagIds.has(id)).toBe(true);
  });

  it("fits the rules' single-choice slots for every type with every capability on", () => {
    const all = Object.fromEntries(CAPABILITIES.map((c) => [c.id, true]));
    for (const t of BUSINESS_TYPE_DEFS) {
      expect(config(t.id, all).extraSingles).toEqual([]);
    }
  });
});

describe("computeMenuConfig", () => {
  it.each(BUSINESS_TYPE_DEFS.map((t) => t.id))("%s: diet first and required, defaults applied", (id) => {
    const c = config(id);
    expect(c.tagGroups[0].id).toBe("diet");
    expect(c.tagGroups[0].required).toBe(true);
    expect(c.allowedDietIds).toEqual(expect.arrayContaining(["vegetarian"]));
    expect(c.inputs.businessType).toBe(id);
    expect(c.terminology.itemLabel).toBe(typeOf(id)!.terminology.itemLabel);
    expect(c.starterCategories.length).toBeGreaterThan(0);
    // The diet group is stored in dietaryLabelId, never in tagIds (D1).
    expect(c.allowedTagIds).not.toContain("vegetarian");
  });

  it("bar: serves alcohol by default (alcohol group, sizes, ABV, notice, filter, noindex)", () => {
    const c = config("bar");
    expect(c.capabilities.servesAlcohol).toBe(true);
    expect(groupIds(c)).toContain("alcohol");
    expect(c.itemFields).toEqual(["servingSizes", "abv"]);
    expect(c.notices).toEqual(["alcohol"]);
    expect(c.filters).toContainEqual({ id: "non-alcoholic", kind: "tag" });
    expect(c.seoIndexableDefault).toBe(false);
    expect(c.terminology.itemLabel).toBe("Drink");
    expect(c.starterCategories.map((x) => x.name)).toContain("Cocktails");
  });

  it("alcohol group: alcoholic and non-alcoholic are mutually exclusive", () => {
    const c = config("bar");
    const slots = [c.single0, c.single1, c.single2, c.single3];
    expect(slots).toContainEqual(["alcoholic", "non-alcoholic"]);
    expect(slots).toContainEqual(["mild", "medium", "spicy", "extra-spicy"]);
    expect(slots).toContainEqual(["hot", "cold"]);
  });

  it("switching servesAlcohol off hides the alcohol group, fields, notice and noindex", () => {
    const c = config("bar", { servesAlcohol: false });
    expect(groupIds(c)).not.toContain("alcohol");
    expect(c.itemFields).toEqual([]);
    expect(c.notices).toEqual([]);
    expect(c.seoIndexableDefault).toBe(true);
    expect(c.allowedTagIds).not.toContain("alcoholic");
  });

  it("pure veg hides non-veg, egg and seafood and adds the badge", () => {
    const c = config("restaurant", { pureVeg: true });
    expect(c.allowedDietIds).toEqual(["vegetarian", "vegan", "jain"]);
    expect(allTagIds(c)).not.toEqual(expect.arrayContaining(["non-vegetarian"]));
    expect(allTagIds(c)).not.toContain("contains-egg");
    expect(allTagIds(c)).not.toContain("seafood");
    expect(c.badges).toEqual(["pureVeg"]);
  });

  it("pure veg also wins on a bar", () => {
    const c = config("bar", { pureVeg: true });
    expect(c.allowedDietIds).not.toContain("non-vegetarian");
    expect(groupIds(c)).toContain("alcohol");
  });

  it("bakery: bakery tags, no alcohol or hotel groups", () => {
    const c = config("bakery");
    expect(c.allowedTagIds).toEqual(expect.arrayContaining(["eggless", "sugar-free"]));
    expect(groupIds(c)).not.toContain("alcohol");
    expect(groupIds(c)).not.toContain("hotel");
    expect(c.filters).toContainEqual({ id: "eggless", kind: "tag" });
  });

  it("hotel: hotel tags and the In-Room Dining starter category", () => {
    const c = config("hotel");
    expect(c.capabilities).toMatchObject({ hasRooms: true, multipleOutlets: true, servesAlcohol: false });
    expect(c.allowedTagIds).toContain("in-room");
    expect(c.starterCategories).toContainEqual({ key: "in-room-dining", name: "In-Room Dining" });
  });

  it("restaurant with every capability", () => {
    const c = config("restaurant", { servesAlcohol: true, hasRooms: true, bakeryItems: true });
    expect(groupIds(c)).toEqual(["diet", "spice", "highlights", "bakery", "beverage", "alcohol", "hotel", "allergens"]);
  });

  it("owner can switch off optional groups but never diet", () => {
    const c = config("restaurant", {}, { disabled: ["spice", "diet", "allergens", "unknown"] });
    expect(groupIds(c)).toEqual(["diet", "highlights", "beverage"]);
    expect(c.inputs.disabledTagGroupIds).toEqual(["allergens", "spice"]);
    expect(c.optionalGroupIds).toEqual(["allergens", "beverage", "highlights", "spice"]);
    expect(c.allowedTagIds).not.toContain("spicy");
  });

  it("unknown or missing type falls back to diet only, with a fallback id", () => {
    const c = config(null);
    expect(groupIds(c)).toEqual(["diet"]);
    expect(c.inputs.businessType).toBe("restaurant");
    expect(c.terminology.itemLabel).toBe("Item");
  });

  it("retired tags stay in the config (shown on items) but are not offered", () => {
    const retired = { ...groups.spice, tags: groups.spice.tags.map((t) => (t.id === "mild" ? { ...t, retired: true } : t)) };
    const c = computeMenuConfig({
      type: typeOf("restaurant"), capabilities: caps, tagGroups: { ...groups, spice: retired },
      restaurant: { businessType: "restaurant", capabilities: {}, disabledTagGroupIds: [], customTags: [] },
      plan: { customTags: false, maxCustomTags: 0 },
    });
    expect(allTagIds(c)).toContain("mild");
    expect(c.allowedTagIds).not.toContain("mild");
  });

  it("inactive groups and capabilities are ignored", () => {
    const c = computeMenuConfig({
      type: typeOf("bar"),
      capabilities: { ...caps, servesAlcohol: { ...caps.servesAlcohol, active: false } },
      tagGroups: { ...groups, spice: { ...groups.spice, active: false } },
      restaurant: { businessType: "bar", capabilities: { servesAlcohol: true }, disabledTagGroupIds: [], customTags: [] },
      plan: { customTags: false, maxCustomTags: 0 },
    });
    expect(groupIds(c)).not.toContain("alcohol");
    expect(groupIds(c)).not.toContain("spice");
    expect(c.capabilities).not.toHaveProperty("servesAlcohol");
  });

  describe("custom tags (plan-gated)", () => {
    const custom: CustomTag[] = [
      { id: "c-house", name: "House favourite", groupId: "highlights" },
      { id: "c-two", name: "Two", groupId: "highlights", color: "#112233" },
      { id: "c-diet", name: "Keto", groupId: "diet" },
      { id: "nope", name: "No prefix", groupId: "highlights" },
      { id: "c-gone", name: "Group off", groupId: "alcohol" },
    ];

    it("dropped on a plan without custom tags", () => {
      const c = config("restaurant", {}, { custom });
      expect(allTagIds(c).filter((id) => id.startsWith("c-"))).toEqual([]);
      expect(c.inputs.customTags).toBe(false);
    });

    it("added on Pro, never to diet, only with the prefix, only in enabled groups", () => {
      const c = config("restaurant", {}, { custom, plan: { customTags: true, maxCustomTags: 20 } });
      expect(c.allowedTagIds).toEqual(expect.arrayContaining(["c-house", "c-two"]));
      expect(allTagIds(c)).not.toContain("c-diet");
      expect(allTagIds(c)).not.toContain("nope");
      expect(allTagIds(c)).not.toContain("c-gone");
      const house = c.tagGroups.find((g) => g.id === "highlights")!.tags.find((t) => t.id === "c-house")!;
      expect(house.custom).toBe(true);
    });

    it("capped at maxCustomTags", () => {
      const c = config("restaurant", {}, { custom, plan: { customTags: true, maxCustomTags: 1 } });
      expect(c.allowedTagIds.filter((id) => id.startsWith("c-"))).toEqual(["c-house"]);
    });
  });

  it("is deterministic", () => {
    expect(config("bar", { hasRooms: true })).toEqual(config("bar", { hasRooms: true }));
  });

  it("more single-choice sets than slots spill into extraSingles", () => {
    const extra = Object.fromEntries(
      [1, 2, 3, 4, 5].map((n) => [`s${n}`, {
        id: `s${n}`, name: `S${n}`, sort: 100 + n, active: true, selection: "single" as const, required: false, exclusive: [],
        tags: [`a${n}`, `b${n}`].map((id, i) => ({ id, name: id, icon: "tag", color: "#000000", sort: i, retired: false })),
      }]),
    );
    const c = computeMenuConfig({
      type: { ...typeOf("other")!, tagGroupIds: ["diet", ...Object.keys(extra)] },
      capabilities: caps, tagGroups: { ...groups, ...extra },
      restaurant: { businessType: "other", capabilities: {}, disabledTagGroupIds: [], customTags: [] },
      plan: { customTags: false, maxCustomTags: 0 },
    });
    expect(c.single3).toEqual(["a4", "b4"]);
    expect(c.extraSingles).toEqual([{ ids: ["a5", "b5"] }]);
    expect(SINGLE_SLOTS).toBe(4);
  });
});

describe("effectiveCapabilities", () => {
  it("owner answers override type defaults; unknown keys dropped", () => {
    expect(effectiveCapabilities(typeOf("bar"), caps, { servesAlcohol: false, nope: true })).toEqual({
      pureVeg: false, servesAlcohol: false, hasRooms: false, multipleOutlets: false, bakeryItems: false,
    });
  });
});

describe("checkItemTags", () => {
  const bar = config("bar");

  it("accepts a valid item", () => {
    expect(checkItemTags(bar, "vegetarian", ["non-alcoholic", "cocktail", "spicy"])).toEqual([]);
  });

  it("needs a diet label from the config", () => {
    expect(checkItemTags(bar, null, [])).toEqual([{ kind: "diet-missing" }]);
    const veg = config("restaurant", { pureVeg: true });
    expect(checkItemTags(veg, "non-vegetarian", [])).toEqual([{ kind: "diet-not-allowed", id: "non-vegetarian" }]);
    // Already on the item: kept (hidden, never deleted).
    expect(checkItemTags(veg, "non-vegetarian", [], { dietId: "non-vegetarian" })).toEqual([]);
  });

  it("rejects tags outside the config unless they were already there", () => {
    const off = config("bar", { servesAlcohol: false });
    expect(checkItemTags(off, "vegetarian", ["beer"])).toEqual([{ kind: "tag-not-allowed", id: "beer" }]);
    expect(checkItemTags(off, "vegetarian", ["beer"], { tagIds: ["beer"] })).toEqual([]);
  });

  it("at most one tag per single group and exclusive set", () => {
    expect(checkItemTags(bar, "vegan", ["alcoholic", "non-alcoholic"])).toEqual([
      { kind: "single-conflict", ids: ["alcoholic", "non-alcoholic"] },
    ]);
    expect(checkItemTags(bar, "vegan", ["mild", "spicy"])).toEqual([{ kind: "single-conflict", ids: ["mild", "spicy"] }]);
  });

  it("visibleTagIds drops tags of hidden groups", () => {
    expect(visibleTagIds(config("bar", { servesAlcohol: false }), ["beer", "spicy"])).toEqual(["spicy"]);
  });
});

describe("parsing catalog documents", () => {
  it("round-trips the seed", () => {
    for (const t of BUSINESS_TYPE_DEFS) expect(parseBusinessType(t.id, { ...t })).toEqual(t);
    for (const c of CAPABILITIES) expect(parseCapability(c.id, { ...c })).toEqual(c);
    for (const g of TAG_GROUPS) expect(parseTagGroup(g.id, { ...g })).toEqual(g);
  });

  it("is defensive about bad data", () => {
    expect(parseBusinessType("x", undefined)).toBeNull();
    const g = parseTagGroup("g", { tags: [{ id: "a", color: "red" }, "junk", { name: "no id" }], exclusive: [{ ids: ["a"] }, "x"] });
    expect(g.tags).toEqual([{ id: "a", name: "a", icon: "tag", color: "#5D4037", sort: 0, retired: false }]);
    expect(g.exclusive).toEqual([]);
    expect(g.selection).toBe("multi");
  });

  it("reads restaurant fields", () => {
    expect(restaurantFeatureFields({
      businessType: "bar", capabilities: { servesAlcohol: false, x: "y" }, disabledTagGroupIds: ["spice", 3],
      customTags: [{ id: "c-a", name: "A", groupId: "highlights", color: "bad" }, { id: "" }],
    })).toEqual({
      businessType: "bar", capabilities: { servesAlcohol: false }, disabledTagGroupIds: ["spice"],
      customTags: [{ id: "c-a", name: "A", groupId: "highlights" }],
    });
  });
});
