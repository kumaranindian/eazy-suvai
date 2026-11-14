/**
 * Countries an owner can register in, with the defaults a new restaurant gets
 * (FRD §6.1). Keep in sync with `packages/core/lib/src/geo/countries.dart`.
 *
 * Adding a market is a data change here and in the Dart list; no other code
 * assumes a country.
 */
export interface CountryDefaults {
  /** ISO 4217 currency code (FRD §6.2). */
  currency: string;
  /** IANA time zone. */
  timezone: string;
}

export const COUNTRIES: Readonly<Record<string, CountryDefaults>> = {
  IN: { currency: "INR", timezone: "Asia/Kolkata" },
  AE: { currency: "AED", timezone: "Asia/Dubai" },
  KW: { currency: "KWD", timezone: "Asia/Kuwait" },
  SA: { currency: "SAR", timezone: "Asia/Riyadh" },
  QA: { currency: "QAR", timezone: "Asia/Qatar" },
  BH: { currency: "BHD", timezone: "Asia/Bahrain" },
  OM: { currency: "OMR", timezone: "Asia/Muscat" },
  US: { currency: "USD", timezone: "America/New_York" },
};

export const COUNTRY_CODES = Object.keys(COUNTRIES) as [string, ...string[]];

/** Business types offered at sign-up (FR-011). Keep in sync with
 * `packages/core/lib/src/geo/business_type.dart`. */
export const BUSINESS_TYPES = [
  "restaurant",
  "cafe",
  "bakery",
  "cloudKitchen",
  "sweetShop",
  "juiceBar",
  "foodTruck",
  "bar",
  "hotel",
  "other",
] as const;
