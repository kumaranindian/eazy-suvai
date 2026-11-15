/**
 * Display formatting for the public menu (M06 preview, M07 page). Prices
 * are integer minor units (BR-019) and are never turned into a float:
 * the major amount is built as a decimal string and formatted by
 * `Intl.NumberFormat`, which takes strings exactly (Node 22).
 */

/** Fraction digits of a currency (INR 2, KWD 3, JPY 0), from CLDR. */
export function currencyDigits(currency: string): number {
  try {
    return new Intl.NumberFormat("en", { style: "currency", currency }).resolvedOptions().maximumFractionDigits ?? 2;
  } catch {
    return 2;
  }
}

/**
 * The major amount as an exact decimal string, for example `129.00` (INR)
 * or `1.250` (KWD). Used for display and for schema.org `price`.
 *
 * @param minor Integer minor units.
 * @param currency ISO 4217 code.
 * @return The decimal string.
 */
export function majorAmount(minor: number, currency: string): string {
  const digits = currencyDigits(currency);
  const negative = minor < 0;
  const abs = String(Math.abs(Math.trunc(minor))).padStart(digits + 1, "0");
  const major = digits === 0 ? abs : `${abs.slice(0, abs.length - digits)}.${abs.slice(abs.length - digits)}`;
  return `${negative ? "-" : ""}${major}`;
}

/**
 * Formats a price for display, for example `₹129.00` (en-IN) or
 * `KWD 1.250` (en-KW).
 *
 * @param minor Integer minor units.
 * @param currency ISO 4217 code.
 * @param locale BCP 47 locale.
 * @return The formatted price.
 */
export function formatPrice(minor: number, currency: string, locale: string): string {
  const digits = currencyDigits(currency);
  const value = majorAmount(minor, currency);
  try {
    const nf = new Intl.NumberFormat(locale, {
      style: "currency",
      currency,
      minimumFractionDigits: digits,
      maximumFractionDigits: digits,
    });
    // Strings are formatted exactly (Intl.NumberFormat v3).
    return nf.format(value as unknown as number);
  } catch {
    return `${currency} ${value}`;
  }
}

/**
 * One day's opening hours for display: `07:00–11:00, 18:00–23:30`,
 * `Closed`, or `Open 24 hours`.
 *
 * @param day The stored day string (architecture §4.2).
 * @param text The words used.
 * @return The display text.
 */
export function formatDayHours(day: string, text: { closed: string; allDay: string }): string {
  if (day === "") return text.closed;
  if (day === "00:00-00:00") return text.allDay;
  return day
    .split(",")
    .map((slot) => slot.replace("-", "–"))
    .join(", ");
}
