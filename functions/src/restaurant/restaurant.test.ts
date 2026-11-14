import { appErrorCodeOf } from "../lib/errors";
import { DEFAULT_RESERVED_SLUGS } from "../auth/slug";
import { handleRestaurantUpdated, restaurantUpdatePatch } from "./on-restaurant-updated";
import { assertSlugAllowed, changeSlugSchema } from "./slug-change";

function codeOf(fn: () => unknown): string | undefined {
  try {
    fn();
  } catch (e) {
    return appErrorCodeOf(e) ?? String(e);
  }
  return undefined;
}

describe("assertSlugAllowed (FR-092)", () => {
  const reserved = DEFAULT_RESERVED_SLUGS;

  it.each(["spice-garden", "abc", "a1-b2-c3", "x".repeat(60), "cafe-2"])("accepts %s", (slug) => {
    expect(codeOf(() => assertSlugAllowed(slug, reserved))).toBeUndefined();
  });

  it.each([
    ["ab", "too short"],
    ["x".repeat(61), "too long"],
    ["-spice", "leading hyphen"],
    ["spice-", "trailing hyphen"],
    ["spice--garden", "double hyphen"],
    ["Spice", "upper case"],
    ["spice_garden", "underscore"],
    ["spice garden", "space"],
    ["café", "accent"],
    ["", "empty"],
  ])("refuses %s (%s) as slug-invalid", (slug) => {
    expect(codeOf(() => assertSlugAllowed(slug, reserved))).toBe("slug-invalid");
  });

  it.each(["admin", "api", "login", "eazysuvai", "avail404", "www", "pricing"])("refuses reserved %s", (slug) => {
    expect(codeOf(() => assertSlugAllowed(slug, reserved))).toBe("slug-reserved");
  });

  it("uses the live reserved list", () => {
    expect(codeOf(() => assertSlugAllowed("biryani", ["biryani"]))).toBe("slug-reserved");
    expect(codeOf(() => assertSlugAllowed("admin", []))).toBeUndefined();
  });
});

describe("changeSlugSchema", () => {
  it("trims and lower-cases the slug", () => {
    expect(changeSlugSchema.parse({ restaurantId: "r1", slug: "  Spice-Garden " }).slug).toBe("spice-garden");
  });

  it("rejects unknown keys and missing fields", () => {
    expect(changeSlugSchema.safeParse({ restaurantId: "r1", slug: "abc", extra: 1 }).success).toBe(false);
    expect(changeSlugSchema.safeParse({ slug: "abc" }).success).toBe(false);
    expect(changeSlugSchema.safeParse({ restaurantId: "r1", slug: "abc", dryRun: "yes" }).success).toBe(false);
  });
});

describe("restaurantUpdatePatch", () => {
  const base = { name: "Spice Garden", nameLower: "spice garden", currency: "INR", publishedVersion: 3 };

  it("flags prices for review when the currency changes after a publish (FR-103)", () => {
    expect(restaurantUpdatePatch(base, { ...base, currency: "AED" })).toEqual({ pricesNeedReview: true });
  });

  it("does not flag before the first publish", () => {
    const draft = { ...base, publishedVersion: null };
    expect(restaurantUpdatePatch(draft, { ...draft, currency: "AED" })).toBeNull();
  });

  it("does not write when the flag is already set", () => {
    expect(restaurantUpdatePatch(base, { ...base, currency: "AED", pricesNeedReview: true })).toBeNull();
  });

  it("keeps nameLower in sync", () => {
    expect(restaurantUpdatePatch(base, { ...base, name: "Spice Garden Café" })).toEqual({
      nameLower: "spice garden café",
    });
  });

  it("produces both changes together", () => {
    expect(restaurantUpdatePatch(base, { ...base, name: "New", currency: "KWD" })).toEqual({
      nameLower: "new",
      pricesNeedReview: true,
    });
  });

  it("is a no-op for unrelated changes and for its own write (no loop)", () => {
    expect(restaurantUpdatePatch(base, { ...base, description: "Hello" })).toBeNull();
    const after = { ...base, currency: "AED", pricesNeedReview: true };
    expect(restaurantUpdatePatch(after, after)).toBeNull();
    expect(restaurantUpdatePatch(undefined, base)).toBeNull();
    expect(restaurantUpdatePatch(base, undefined)).toBeNull();
  });

  it("handleRestaurantUpdated writes only when needed", async () => {
    const update = jest.fn().mockResolvedValue(undefined);
    await handleRestaurantUpdated({ update } as never, base, { ...base, description: "x" });
    expect(update).not.toHaveBeenCalled();
    await handleRestaurantUpdated({ update } as never, base, { ...base, currency: "USD" });
    expect(update).toHaveBeenCalledWith({ pricesNeedReview: true });
  });
});
