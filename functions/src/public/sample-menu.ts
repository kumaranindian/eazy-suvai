/**
 * A realistic published snapshot (6 categories, 36 items) for the template
 * snapshot tests, the emulator tests and the Lighthouse budget run
 * (`scripts/lighthouse-budget.mjs`). Not used by any deployed function.
 */
import type { MenuSnapshot, SnapshotImage, SnapshotItem, SnapshotLabel } from "../publishing/snapshot";
import { resolveTheme, SEED_THEMES } from "../theme";

/** Builds an image for a name: `(name) => {width, height, w320, w640, w1280}`. */
export type SampleImageFor = (name: string) => SnapshotImage;

export const sampleImage: SampleImageFor = (name) => ({
  width: 1200,
  height: 900,
  w320: `https://img.test/${name}/w320.webp`,
  w640: `https://img.test/${name}/w640.webp`,
  w1280: `https://img.test/${name}/w1280.webp`,
});

const VEG: SnapshotLabel = { id: "vegetarian", name: "Vegetarian", icon: "veg", color: "#0F7B0F" };
const NON_VEG: SnapshotLabel = { id: "non-vegetarian", name: "Non-vegetarian", icon: "nonVeg", color: "#8B2E16" };
const VEGAN: SnapshotLabel = { id: "vegan", name: "Vegan", icon: "vegan", color: "#2E7D32" };
const SPICY: SnapshotLabel = { id: "spicy", name: "Spicy", icon: "spicy", color: "#C62828" };
const BEST: SnapshotLabel = { id: "bestseller", name: "Bestseller", icon: "bestseller", color: "#A8550A" };

const CATEGORIES: [string, string, string | null][] = [
  ["tiffin", "Tiffin", "Served from 7 am to 11 am."],
  ["meals", "Meals", null],
  ["biryani", "Biryani", "Slow-cooked on dum, served with raita and salna."],
  ["chinese", "Indo-Chinese", null],
  ["desserts", "Desserts", null],
  ["drinks", "Drinks", null],
];

const DISHES: Record<string, [string, number, SnapshotLabel | null, string?][]> = {
  tiffin: [
    ["Idli (2 pcs)", 6000, VEG, "Steamed rice cakes with sambar and three chutneys."],
    ["Ghee Roast Dosa", 12900, VEG, "A crisp, golden dosa roasted in pure ghee, served with coconut chutney, tomato chutney and a bowl of hot sambar. Ask for it extra crispy if you like."],
    ["Medu Vada (2 pcs)", 7000, VEG],
    ["Pongal", 9000, VEG, "Rice and moong dal with pepper, cumin and cashews."],
    ["Poori Masala", 9900, VEG],
    ["Rava Kesari", 5000, VEG],
  ],
  meals: [
    ["South Indian Meals", 18000, VEG, "Rice, sambar, rasam, two poriyal, kootu, appalam, curd and payasam."],
    ["Chettinad Chicken Meals", 26000, NON_VEG],
    ["Fish Curry Meals", 28000, NON_VEG, "Tangy tamarind fish curry with rice and sides."],
    ["Curd Rice", 9000, VEG],
    ["Lemon Rice", 9000, VEGAN],
    ["Sambar Rice", 10000, VEG],
  ],
  biryani: [
    ["Chicken Biryani", 24000, NON_VEG, "Seeraga samba rice, country chicken, and our house masala."],
    ["Mutton Biryani", 32000, NON_VEG],
    ["Egg Biryani", 18000, NON_VEG],
    ["Veg Biryani", 16000, VEG],
    ["Prawn Biryani", 34000, NON_VEG],
    ["Mushroom Biryani", 17000, VEG],
  ],
  chinese: [
    ["Gobi Manchurian", 16000, VEG],
    ["Chilli Chicken", 22000, NON_VEG],
    ["Veg Fried Rice", 15000, VEG],
    ["Schezwan Noodles", 16000, VEG],
    ["Chicken 65", 22000, NON_VEG, "Deep-fried, curry leaf tempered, fiery red."],
    ["Paneer Chilli", 20000, VEG],
  ],
  desserts: [
    ["Gulab Jamun (2 pcs)", 6000, VEG],
    ["Elaneer Payasam", 12000, VEG, "Tender coconut kheer, served chilled."],
    ["Carrot Halwa", 9000, VEG],
    ["Kulfi", 8000, VEG],
    ["Fruit Salad with Ice Cream", 11000, VEG],
    ["Double Ka Meetha", 10000, VEG],
  ],
  drinks: [
    ["Filter Coffee", 4000, VEG, "Degree coffee, brewed fresh."],
    ["Masala Tea", 3500, VEG],
    ["Fresh Lime Soda", 6000, VEGAN],
    ["Rose Milk", 7000, VEG],
    ["Buttermilk", 4000, VEG],
    ["Mango Lassi", 9000, VEG],
  ],
};

/** Every item with a photo except every third, the first two featured, one sold out. */
export function sampleSnapshot(imageFor: SampleImageFor = sampleImage): MenuSnapshot {
  const saffron = SEED_THEMES.find((t) => t.id === "saffron")!;
  const resolved: Partial<ReturnType<typeof resolveTheme>> = resolveTheme(saffron.tokens, {});
  delete resolved.issues;
  const items: SnapshotItem[] = [];
  let n = 0;
  for (const [cid] of CATEGORIES) {
    DISHES[cid].forEach(([name, priceMinor, label, description], i) => {
      n++;
      const item: SnapshotItem = {
        id: `${cid}-${i + 1}`,
        categoryId: cid,
        name,
        priceMinor,
        dietaryLabel: label,
        tags: n === 2 ? [BEST] : name.includes("Chilli") || name.includes("65") ? [SPICY] : [],
        available: true,
        featured: n === 2 || n === 13,
        sequence: (i + 1) * 1000,
      };
      if (description) item.description = description;
      if (n % 3 !== 0) item.image = imageFor(`item-${item.id}`);
      items.push(item);
    });
  }
  items.find((i) => i.id === "biryani-2")!.available = false;
  return {
    schema: 1,
    profile: {
      name: "Spice Garden",
      businessType: "restaurant",
      description: "South Indian classics, biryani and filter coffee since 1998.",
      logo: imageFor("logo"),
      cover: imageFor("cover"),
      contact: {
        phone: "+914423456789",
        email: "hello@spicegarden.example",
        address: "12 Anna Salai",
        city: "Chennai",
        postalCode: "600002",
        website: "https://spicegarden.example",
        social: { instagram: "https://instagram.com/spicegarden" },
      },
      openingHours: {
        mon: "07:00-11:00,18:00-23:30",
        tue: "07:00-11:00,18:00-23:30",
        wed: "07:00-11:00,18:00-23:30",
        thu: "07:00-11:00,18:00-23:30",
        fri: "07:00-11:00,18:00-01:00",
        sat: "00:00-00:00",
        sun: "",
      },
    },
    theme: { themeId: "saffron", tokens: saffron.tokens, settings: {}, resolved: resolved as MenuSnapshot["theme"]["resolved"] },
    categories: CATEGORIES.map(([id, name, description], i) => ({ id, name, sequence: (i + 1) * 1000, ...(description ? { description } : {}) })),
    items,
    currency: "INR",
    locale: "en-IN",
    timezone: "Asia/Kolkata",
  };
}
