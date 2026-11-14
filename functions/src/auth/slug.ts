/**
 * Slug rules (FR-092): lowercase a–z, 0–9 and single hyphens, 3–60
 * characters, no leading or trailing hyphen, not a reserved word.
 */
export const SLUG_MIN = 3;
export const SLUG_MAX = 60;

/** Starting reserved list from FR-092. The admin maintains the live list in
 * `config/platform.reservedSlugs`; this is used when that field is missing. */
export const DEFAULT_RESERVED_SLUGS: readonly string[] = [
  "admin", "api", "app", "assets", "blog", "dashboard", "help", "login",
  "logout", "m", "pricing", "privacy", "q", "robots.txt", "signup",
  "sitemap.xml", "static", "support", "terms", "www", "eazysuvai", "avail404",
];

/** Used when the name has no Latin letters or digits (for example a name
 * written only in Tamil script). */
export const FALLBACK_SLUG_BASE = "restaurant";

const SLUG_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

/**
 * Turns free text into slug form: strips accents, lowercases, replaces any
 * run of other characters with one hyphen and trims to [maxLength].
 *
 * @param text Restaurant name or city.
 * @param maxLength Maximum length of the result.
 * @return The slug part, possibly empty.
 */
export function slugify(text: string, maxLength = SLUG_MAX): string {
  const ascii = text
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/['’]/g, "");
  const slug = ascii.replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
  return trimSlug(slug, maxLength);
}

/** Cuts [slug] to [maxLength] without leaving a trailing hyphen. */
function trimSlug(slug: string, maxLength: number): string {
  if (slug.length <= maxLength) return slug;
  return slug.slice(0, maxLength).replace(/-+$/, "");
}

/**
 * Checks the FR-092 format and the reserved list.
 *
 * @param slug Candidate slug.
 * @param reserved Reserved words.
 * @return Whether the slug may be used.
 */
export function isValidSlug(slug: string, reserved: readonly string[] = DEFAULT_RESERVED_SLUGS): boolean {
  return (
    slug.length >= SLUG_MIN &&
    slug.length <= SLUG_MAX &&
    SLUG_RE.test(slug) &&
    !reserved.includes(slug)
  );
}

/** Appends `-suffix`, shortening [base] so the result fits in [SLUG_MAX]. */
function withSuffix(base: string, suffix: string): string {
  const room = SLUG_MAX - suffix.length - 1;
  return `${trimSlug(base, room)}-${suffix}`;
}

/**
 * Candidate slugs in the FR-092 order: the name, then name + city, then
 * name + city + 2, 3, … (or name + 2, 3, … without a city). Invalid and
 * reserved candidates are skipped.
 *
 * @param name Restaurant name.
 * @param city Optional city.
 * @param reserved Reserved words.
 * @param count How many candidates to return.
 * @param startNumber First number suffix to use.
 * @return Valid, distinct candidates.
 */
export function slugCandidates(
  name: string,
  city: string | undefined,
  reserved: readonly string[],
  count: number,
  startNumber = 2,
): string[] {
  let base = slugify(name);
  if (base.length < SLUG_MIN) base = FALLBACK_SLUG_BASE;
  const citySlug = city ? slugify(city, 30) : "";
  const numbered = citySlug && citySlug !== base ? withSuffix(base, citySlug) : base;

  const out: string[] = [];
  const add = (s: string) => {
    if (isValidSlug(s, reserved) && !out.includes(s)) out.push(s);
  };
  if (startNumber <= 2) {
    add(base);
    add(numbered);
  }
  for (let n = Math.max(startNumber, 2); out.length < count; n++) {
    add(withSuffix(numbered, String(n)));
  }
  return out.slice(0, count);
}
