/**
 * Customer-facing words of the public menu (FRD §6.3: English in the MVP).
 *
 * Every string the public pages show lives here, never inline in a
 * template, so adding a language means adding one more object of the same
 * shape and choosing it by locale in {@link menuText}.
 */
import type { Weekday } from "../publishing/snapshot";

export const MENU_TEXT_EN = {
  menu: "Menu",
  titleSuffix: "Menu | EazySuvai",
  skip: "Skip to menu",
  categories: "Categories",
  featured: "Featured",
  soldOut: "Currently unavailable",
  closed: "Closed",
  allDay: "Open 24 hours",
  hours: "Opening hours",
  openNow: "Open now",
  closedNow: "Closed now",
  call: "Call",
  email: "Email",
  website: "Website",
  map: "Map",
  more: "more",
  less: "less",
  close: "Close",
  enlarge: "Enlarge photo of",
  poweredBy: "Powered by EazySuvai",
  previewBanner: "Preview – this is your unpublished draft. Customers can't see it yet.",
  empty: "This menu has no items yet.",
  /** Meta description when the owner wrote none: `{name}` and `{place}` are filled in. */
  defaultDescription: "See the menu of {name}{place}: dishes, prices and opening hours.",
  days: {
    mon: "Monday",
    tue: "Tuesday",
    wed: "Wednesday",
    thu: "Thursday",
    fri: "Friday",
    sat: "Saturday",
    sun: "Sunday",
  } as Record<Weekday, string>,
  social: {
    instagram: "Instagram",
    facebook: "Facebook",
    x: "X",
    youtube: "YouTube",
    googleMaps: "Google Maps",
  } as Record<string, string>,
  states: {
    comingSoonTitle: "Menu coming soon",
    comingSoonBody: "{name} is getting its menu ready. Please check back soon.",
    unavailableTitle: "Menu temporarily unavailable",
    unavailableBody: "The menu of {name} can't be shown right now. Please try again later.",
    goneTitle: "Menu no longer available",
    goneBody: "This menu is no longer available.",
    notFoundTitle: "Menu not found",
    notFoundBody: "We couldn't find a menu at this address. Check the link or scan the QR code again.",
    errorTitle: "Something went wrong",
    errorBody: "We couldn't load this menu. Please try again in a moment.",
    retry: "Try again",
    /** Used for {name} when the restaurant has no name. */
    someRestaurant: "This restaurant",
    someRestaurantLower: "this restaurant",
  },
};

export type MenuText = typeof MENU_TEXT_EN;

/** Bundles by language subtag. */
const TEXTS: Record<string, MenuText> = { en: MENU_TEXT_EN };

/**
 * The words for a locale. Only English exists in the MVP; every locale
 * falls back to it.
 *
 * @param locale BCP 47 locale of the restaurant, for example `en-IN`.
 * @return The text bundle.
 */
export function menuText(locale?: string): MenuText {
  return TEXTS[(locale ?? "en").split("-")[0]] ?? MENU_TEXT_EN;
}

/** Fills `{key}` placeholders. Values are plain text; escape the result when it goes into HTML. */
export function fill(template: string, values: Record<string, string>): string {
  return template.replace(/\{(\w+)\}/g, (m, k: string) => (k in values ? values[k] : m));
}
