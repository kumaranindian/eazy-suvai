/**
 * How long an open menu page keeps checking for changes (`live.json`).
 * Platform settings in `config/platform`, edited by admins (M11 settings):
 *
 * - `liveIdleMinutes`: stop after this long without a tap, scroll or key;
 *   activity or coming back to the tab starts the checks again.
 * - `liveMaxMinutes`: stop for good this long after the page was opened
 *   (one scan or visit); opening the link again starts a new session.
 *
 * A missing or invalid value uses the default, so the menu never depends on
 * the document existing.
 */

type Data = Record<string, unknown>;

export const LIVE_IDLE_MINUTES = { min: 1, max: 240, default: 30 } as const;
export const LIVE_MAX_MINUTES = { min: 5, max: 720, default: 120 } as const;

export interface LiveLimits {
  idleMinutes: number;
  maxMinutes: number;
}

function inRange(v: unknown, r: { min: number; max: number; default: number }): number {
  return typeof v === "number" && Number.isInteger(v) && v >= r.min && v <= r.max ? v : r.default;
}

/**
 * The limits from `config/platform` data, with defaults for anything
 * missing or out of range.
 *
 * @param config `config/platform` data, or undefined.
 * @return The idle and maximum minutes.
 */
export function liveLimitsOf(config: Data | undefined): LiveLimits {
  return {
    idleMinutes: inRange(config?.liveIdleMinutes, LIVE_IDLE_MINUTES),
    maxMinutes: inRange(config?.liveMaxMinutes, LIVE_MAX_MINUTES),
  };
}
