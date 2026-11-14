import { DEFAULT_RESERVED_SLUGS, isValidSlug, slugCandidates, slugify, SLUG_MAX } from "./slug";

describe("slugify", () => {
  it.each([
    ["Spice Garden", "spice-garden"],
    ["  Café   Délice!! ", "cafe-delice"],
    ["Rock & Roll Diner", "rock-and-roll-diner"],
    ["Raja's   Kitchen", "rajas-kitchen"],
    ["--A--B--", "a-b"],
    ["சரவண பவன்", ""],
    ["Hotel 7 Stars", "hotel-7-stars"],
  ])("%s → %s", (input, expected) => {
    expect(slugify(input)).toBe(expected);
  });

  it("never exceeds 60 characters or ends with a hyphen", () => {
    const s = slugify("a".repeat(59) + " bcd");
    expect(s.length).toBeLessThanOrEqual(SLUG_MAX);
    expect(s.endsWith("-")).toBe(false);
  });
});

describe("isValidSlug (FR-092)", () => {
  it.each(["abc", "spice-garden", "a1-b2", "x".repeat(60)])("accepts %s", (s) => {
    expect(isValidSlug(s)).toBe(true);
  });
  it.each(["ab", "x".repeat(61), "-abc", "abc-", "a--b", "ABC", "a_b", "admin", "robots.txt", "eazysuvai"])(
    "rejects %s",
    (s) => {
      expect(isValidSlug(s)).toBe(false);
    },
  );
});

describe("slugCandidates", () => {
  const reserved = DEFAULT_RESERVED_SLUGS;

  it("uses name, then name + city, then numbers (FR-092 example)", () => {
    expect(slugCandidates("Spice Garden", "Chennai", reserved, 4)).toEqual([
      "spice-garden",
      "spice-garden-chennai",
      "spice-garden-chennai-2",
      "spice-garden-chennai-3",
    ]);
  });

  it("numbers the name when there is no city", () => {
    expect(slugCandidates("Spice Garden", undefined, reserved, 3)).toEqual([
      "spice-garden",
      "spice-garden-2",
      "spice-garden-3",
    ]);
  });

  it("skips reserved words", () => {
    expect(slugCandidates("Admin", "Chennai", reserved, 2)).toEqual(["admin-chennai", "admin-chennai-2"]);
    expect(slugCandidates("Admin", undefined, reserved, 2)).toEqual(["admin-2", "admin-3"]);
  });

  it("falls back to 'restaurant' for names without Latin letters", () => {
    expect(slugCandidates("சரவண பவன்", "Chennai", reserved, 2)).toEqual([
      "restaurant",
      "restaurant-chennai",
    ]);
  });

  it("continues numbering from startNumber", () => {
    expect(slugCandidates("Spice Garden", "Chennai", reserved, 2, 10)).toEqual([
      "spice-garden-chennai-10",
      "spice-garden-chennai-11",
    ]);
  });

  it("keeps long names within 60 characters with suffixes", () => {
    const name = "The Very Long Name Of A Restaurant That Goes On And On Forever More";
    for (const s of slugCandidates(name, "Thiruvananthapuram", reserved, 5)) {
      expect(isValidSlug(s)).toBe(true);
    }
  });
});
