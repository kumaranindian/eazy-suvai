/**
 * Opening hours on the public menu: "Open now / Closed" in the restaurant's
 * IANA time zone (FRD §6.4) and schema.org `openingHoursSpecification`.
 *
 * Day strings follow architecture §4.2: `"07:00-11:00,18:00-23:30"`, `""`
 * closed, `"00:00-00:00"` open all day, and a close before the open runs
 * past midnight (into the next day).
 */
import { WEEKDAYS, type Weekday } from "../publishing/snapshot";

const SLOT = /^([01]\d|2[0-3]):([0-5]\d)-([01]\d|2[0-3]):([0-5]\d)$/;

interface Slot {
  open: number;
  close: number;
  raw: [string, string];
}

function slotsOf(day: string | undefined): Slot[] {
  if (!day) return [];
  const out: Slot[] = [];
  for (const part of day.split(",")) {
    const m = SLOT.exec(part.trim());
    if (!m) continue;
    out.push({
      open: Number(m[1]) * 60 + Number(m[2]),
      close: Number(m[3]) * 60 + Number(m[4]),
      raw: [`${m[1]}:${m[2]}`, `${m[3]}:${m[4]}`],
    });
  }
  return out;
}

const SHORT_TO_DAY: Record<string, Weekday> = {
  Mon: "mon",
  Tue: "tue",
  Wed: "wed",
  Thu: "thu",
  Fri: "fri",
  Sat: "sat",
  Sun: "sun",
};

/**
 * The weekday and minute of the day at `now` in `timeZone`.
 *
 * @param now The instant.
 * @param timeZone IANA name; an unknown zone falls back to UTC.
 * @return `{day, minute}`.
 */
export function localTime(now: Date, timeZone: string): { day: Weekday; minute: number } {
  let parts: Intl.DateTimeFormatPart[];
  try {
    parts = new Intl.DateTimeFormat("en-US", {
      timeZone,
      weekday: "short",
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    }).formatToParts(now);
  } catch {
    return localTime(now, "UTC");
  }
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? "";
  const hour = Number(get("hour")) % 24;
  return { day: SHORT_TO_DAY[get("weekday")] ?? "mon", minute: hour * 60 + Number(get("minute")) };
}

/**
 * Whether the restaurant is open at `now`.
 *
 * @param hours One string per weekday, or undefined when hidden or not set.
 * @param timeZone The restaurant's IANA time zone.
 * @param now The instant to check.
 * @return true or false, or null when there are no hours to judge by.
 */
export function isOpenAt(hours: Partial<Record<Weekday, string>> | undefined, timeZone: string, now: Date): boolean | null {
  if (!hours) return null;
  const all = WEEKDAYS.map((d) => hours[d] ?? "");
  if (all.every((d) => d === "")) return null;
  const { day, minute } = localTime(now, timeZone);
  const idx = WEEKDAYS.indexOf(day);
  const yesterday = WEEKDAYS[(idx + 6) % 7];
  for (const s of slotsOf(hours[day])) {
    if (s.open === s.close) return true; // 00:00-00:00: all day
    if (s.open < s.close ? minute >= s.open && minute < s.close : minute >= s.open) return true;
  }
  // Yesterday's slots that run past midnight.
  for (const s of slotsOf(hours[yesterday])) {
    if (s.close < s.open && minute < s.close) return true;
  }
  return false;
}

const SCHEMA_DAY: Record<Weekday, string> = {
  mon: "https://schema.org/Monday",
  tue: "https://schema.org/Tuesday",
  wed: "https://schema.org/Wednesday",
  thu: "https://schema.org/Thursday",
  fri: "https://schema.org/Friday",
  sat: "https://schema.org/Saturday",
  sun: "https://schema.org/Sunday",
};

/**
 * schema.org `OpeningHoursSpecification` entries, one per slot. Closed days
 * are left out; an all-day slot is 00:00–23:59; a slot past midnight keeps
 * its earlier close time, which schema.org reads as the next day.
 *
 * @param hours One string per weekday.
 * @return The JSON-LD entries.
 */
export function openingHoursSpecification(hours: Partial<Record<Weekday, string>> | undefined): Record<string, string>[] {
  if (!hours) return [];
  const out: Record<string, string>[] = [];
  for (const d of WEEKDAYS) {
    for (const s of slotsOf(hours[d])) {
      const closes = s.open === s.close ? "23:59" : s.raw[1];
      out.push({ "@type": "OpeningHoursSpecification", dayOfWeek: SCHEMA_DAY[d], opens: s.raw[0], closes });
    }
  }
  return out;
}
