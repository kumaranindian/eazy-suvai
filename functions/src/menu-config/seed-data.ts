/**
 * Initial business types, capabilities and tag groups (M14). Written by
 * `scripts/seed-platform.mjs`; platform admins manage them afterwards
 * (admin app → Catalog).
 *
 * Ids are stable and never reused: items store bare tag ids (D2). The
 * diet group keeps the M04 dietary label ids and colours; `spicy`,
 * `bestseller`, `chefs-special` and `new` keep their M04 ids, so existing
 * items need no rewrite.
 *
 * `icon` is a key the apps and the public menu draw (unknown keys fall back
 * to a generic tag icon), not a URL.
 */
import { DIETARY_LABELS, ITEM_TAGS } from "../menu/seed-data";
import type { BusinessTypeDef, CapabilityDef, TagDef, TagGroupDef } from "./types";

function tag(id: string, name: string, icon: string, color: string, sort: number, filter = false): TagDef {
  return { id, name, icon, color, sort, retired: false, ...(filter ? { filter: true } : {}) };
}

const legacyTag = (id: string, sort: number): TagDef => {
  const t = ITEM_TAGS.find((x) => x.id === id);
  if (!t) throw new Error(`Unknown legacy tag ${id}`);
  return { id: t.id, name: t.name, icon: t.icon, color: t.color, sort, retired: false };
};

const DIET_FILTERS = new Set(["vegetarian", "vegan"]);

export const TAG_GROUPS: readonly TagGroupDef[] = [
  {
    id: "diet",
    name: "Diet",
    sort: 10,
    active: true,
    selection: "single",
    required: true,
    exclusive: [],
    tags: [
      ...DIETARY_LABELS.map((l) => ({
        id: l.id, name: l.name, icon: l.icon, color: l.color, sort: l.sort, retired: false,
        ...(DIET_FILTERS.has(l.id) ? { filter: true } : {}),
      })),
      tag("jain", "Jain", "jain", "#2E7D32", 50, true),
    ],
  },
  {
    id: "spice",
    name: "Spice level",
    sort: 20,
    active: true,
    selection: "single",
    required: false,
    exclusive: [],
    tags: [
      tag("mild", "Mild", "spicy", "#E65100", 10),
      tag("medium", "Medium", "spicy", "#D84315", 20),
      legacyTag("spicy", 30),
      tag("extra-spicy", "Extra spicy", "spicy", "#8E0000", 40),
    ],
  },
  {
    id: "highlights",
    name: "Highlights",
    sort: 30,
    active: true,
    selection: "multi",
    required: false,
    exclusive: [],
    tags: [
      legacyTag("bestseller", 10),
      legacyTag("chefs-special", 20),
      legacyTag("new", 30),
      tag("recommended", "Recommended", "recommended", "#2E7D32", 40),
    ],
  },
  {
    id: "bakery",
    name: "Bakery",
    sort: 40,
    active: true,
    selection: "multi",
    required: false,
    exclusive: [],
    tags: [
      tag("eggless", "Eggless", "eggless", "#2E7D32", 10, true),
      tag("sugar-free", "Sugar-free", "sugarFree", "#1565C0", 20, true),
      tag("gluten-free", "Gluten-free", "glutenFree", "#6D4C41", 30, true),
      tag("order-in-advance", "Order in advance", "clock", "#5D4037", 40),
    ],
  },
  {
    id: "beverage",
    name: "Beverage",
    sort: 50,
    active: true,
    selection: "multi",
    required: false,
    exclusive: [{ ids: ["hot", "cold"] }],
    tags: [
      tag("hot", "Hot", "hot", "#C62828", 10),
      tag("cold", "Cold", "cold", "#1565C0", 20),
      tag("contains-caffeine", "Contains caffeine", "caffeine", "#5D4037", 30),
      tag("fresh", "Fresh", "fresh", "#2E7D32", 40),
    ],
  },
  {
    id: "alcohol",
    name: "Alcohol",
    sort: 60,
    active: true,
    selection: "multi",
    required: false,
    exclusive: [{ ids: ["alcoholic", "non-alcoholic"] }],
    tags: [
      tag("alcoholic", "Alcoholic", "alcohol", "#6A1B9A", 10),
      tag("non-alcoholic", "Non-alcoholic", "noAlcohol", "#2E7D32", 20, true),
      tag("beer", "Beer", "beer", "#B26A00", 30),
      tag("wine", "Wine", "wine", "#880E4F", 40),
      tag("spirit", "Spirit", "spirit", "#4E342E", 50),
      tag("cocktail", "Cocktail", "cocktail", "#AD1457", 60),
    ],
  },
  {
    id: "hotel",
    name: "Hotel",
    sort: 70,
    active: true,
    selection: "multi",
    required: false,
    exclusive: [],
    tags: [
      tag("in-room", "In-room dining", "roomService", "#1565C0", 10, true),
      tag("available-24h", "Available 24 hours", "clock", "#37474F", 20),
      tag("breakfast-only", "Breakfast only", "breakfast", "#B26A00", 30),
    ],
  },
  {
    id: "allergens",
    name: "Allergens",
    sort: 80,
    active: true,
    selection: "multi",
    required: false,
    exclusive: [],
    tags: [
      tag("nuts", "Contains nuts", "allergen", "#6D4C41", 10),
      tag("dairy", "Contains dairy", "allergen", "#1565C0", 20),
      tag("gluten", "Contains gluten", "allergen", "#B26A00", 30),
      tag("seafood", "Contains seafood", "allergen", "#00695C", 40),
    ],
  },
];

export const CAPABILITIES: readonly CapabilityDef[] = [
  {
    id: "pureVeg",
    question: "Is everything you serve vegetarian?",
    help: "Hides the non-vegetarian and egg labels and shows a Pure Veg badge on your menu.",
    sort: 10,
    active: true,
    addTagGroupIds: [],
    hideTagGroupIds: [],
    hideTagIds: ["non-vegetarian", "contains-egg", "seafood"],
    addItemFields: [],
    addNotices: [],
    addBadges: ["pureVeg"],
    addCategories: [],
  },
  {
    id: "servesAlcohol",
    question: "Do you serve alcohol?",
    help: "Adds alcohol tags, serving sizes and ABV, and an age notice on your menu.",
    sort: 20,
    active: true,
    addTagGroupIds: ["alcohol"],
    hideTagGroupIds: [],
    hideTagIds: [],
    addItemFields: ["servingSizes", "abv"],
    addNotices: ["alcohol"],
    addBadges: [],
    addCategories: [],
    seoIndexableDefault: false,
  },
  {
    id: "hasRooms",
    question: "Do you have guest rooms?",
    help: "Adds hotel tags such as in-room dining and an In-Room Dining category.",
    sort: 30,
    active: true,
    addTagGroupIds: ["hotel"],
    hideTagGroupIds: [],
    hideTagIds: [],
    addItemFields: [],
    addNotices: [],
    addBadges: [],
    addCategories: [{ key: "in-room-dining", name: "In-Room Dining" }],
  },
  {
    id: "multipleOutlets",
    question: "Do you have more than one outlet?",
    help: "We'll use this when outlets arrive. Nothing changes on your menu yet.",
    sort: 40,
    active: true,
    addTagGroupIds: [],
    hideTagGroupIds: [],
    hideTagIds: [],
    addItemFields: [],
    addNotices: [],
    addBadges: [],
    addCategories: [],
  },
  {
    id: "bakeryItems",
    question: "Do you sell baked goods?",
    help: "Adds bakery tags such as eggless and sugar-free.",
    sort: 50,
    active: true,
    addTagGroupIds: ["bakery"],
    hideTagGroupIds: [],
    hideTagIds: [],
    addItemFields: [],
    addNotices: [],
    addBadges: [],
    addCategories: [],
  },
];

const FOOD = ["diet", "spice", "highlights", "beverage", "allergens"];
const NONE = { pureVeg: false, servesAlcohol: false, hasRooms: false, multipleOutlets: false, bakeryItems: false };
const ITEM = { itemLabel: "Item", itemLabelPlural: "Items" };
const DISH = { itemLabel: "Dish", itemLabelPlural: "Dishes" };
const DRINK = { itemLabel: "Drink", itemLabelPlural: "Drinks" };
const cats = (...names: string[]) =>
  names.map((name) => ({ key: name.toLowerCase().replace(/&/g, "and").replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, ""), name }));

function type(
  id: string, name: string, icon: string, sort: number, schemaType: string,
  terminology: BusinessTypeDef["terminology"], categories: string[],
  defaults: Partial<typeof NONE> = {}, tagGroupIds: string[] = FOOD,
): BusinessTypeDef {
  return {
    id, name, icon, sort, active: true, version: 1, terminology,
    defaultCapabilities: { ...NONE, ...defaults },
    defaultCategories: cats(...categories),
    tagGroupIds, itemFields: [], schemaType,
  };
}

/**
 * Business types (D3). The ten M01 ids are kept, so no restaurant document
 * changes; `fastFood`, `club`, `canteen` and `caterer` are new.
 */
export const BUSINESS_TYPE_DEFS: readonly BusinessTypeDef[] = [
  type("restaurant", "Restaurant", "restaurant", 10, "Restaurant", DISH,
    ["Starters", "Main course", "Breads", "Rice & biryani", "Desserts", "Beverages"]),
  type("cafe", "Café", "cafe", 20, "CafeOrCoffeeShop", ITEM,
    ["Coffee", "Tea", "Cold drinks", "Snacks", "Desserts"], {}, ["diet", "highlights", "beverage", "allergens"]),
  type("bakery", "Bakery", "bakery", 30, "Bakery", ITEM,
    ["Cakes", "Pastries", "Breads", "Cookies", "Savouries", "Beverages"], { bakeryItems: true },
    ["diet", "highlights", "beverage", "allergens"]),
  type("sweetShop", "Sweet shop", "sweetShop", 40, "FoodEstablishment", ITEM,
    ["Sweets", "Savouries", "Snacks", "Gift boxes"], { bakeryItems: true }, ["diet", "highlights", "allergens"]),
  type("juiceBar", "Juice bar", "juiceBar", 50, "FoodEstablishment", DRINK,
    ["Fresh juices", "Smoothies", "Milkshakes", "Snacks"], {}, ["diet", "highlights", "beverage", "allergens"]),
  type("fastFood", "Fast food or stall", "fastFood", 60, "FastFoodRestaurant", ITEM,
    ["Burgers", "Sandwiches & wraps", "Sides", "Combos", "Drinks"]),
  type("foodTruck", "Food truck", "foodTruck", 70, "FoodEstablishment", ITEM,
    ["Mains", "Sides", "Combos", "Drinks"]),
  type("bar", "Bar, pub or lounge", "bar", 80, "BarOrPub", DRINK,
    ["Beer", "Wine", "Spirits", "Cocktails", "Mocktails", "Bar bites"], { servesAlcohol: true }),
  type("hotel", "Hotel or resort", "hotel", 90, "Restaurant", DISH,
    ["Breakfast", "Starters", "Main course", "Desserts", "Beverages"], { hasRooms: true, multipleOutlets: true }),
  type("club", "Club", "club", 100, "FoodEstablishment", ITEM,
    ["Snacks", "Main course", "Beverages", "Bar"], { servesAlcohol: true }),
  type("canteen", "Canteen", "canteen", 110, "FoodEstablishment", ITEM,
    ["Breakfast", "Lunch", "Snacks", "Beverages"], {}, ["diet", "spice", "highlights", "beverage"]),
  type("cloudKitchen", "Cloud kitchen", "cloudKitchen", 120, "Restaurant", DISH,
    ["Starters", "Mains", "Combos", "Desserts", "Beverages"]),
  type("caterer", "Caterer", "caterer", 130, "FoodEstablishment", DISH,
    ["Packages", "Starters", "Main course", "Desserts"], {}, ["diet", "spice", "highlights", "allergens"]),
  type("other", "Other", "other", 1000, "FoodEstablishment", ITEM, ["Popular", "More"]),
];

/**
 * Alcohol notices by region (D9): ISO 3166-2 (`IN-TN`), then country
 * (`IN`), then `default`. PLACEHOLDERS from the M14 request: a platform
 * admin must check the ages and wording before launch.
 */
export const ALCOHOL_NOTICES: Readonly<Record<string, { minAge: number; text: string }>> = {
  "IN-TN": { minAge: 21, text: "Alcohol is served only to guests aged 21 or over. Please drink responsibly." },
  "IN-PY": { minAge: 18, text: "Alcohol is served only to guests aged 18 or over. Please drink responsibly." },
  "default": { minAge: 18, text: "Alcohol is served only to guests of legal drinking age. Please drink responsibly." },
};
