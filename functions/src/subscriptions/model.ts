/**
 * Subscriptions as a pure state machine (M10, FR-079 to FR-083, FR-100).
 * No Firestore and no clock here: `daily.ts` reads the restaurants and
 * applies what {@link dailyActionFor} decides for "now", so every
 * transition is tested with fixed dates.
 *
 * `restaurants/{rid}.subscription`:
 * `{status: 'free'|'active'|'grace', planId, billing, startAt, expiresAt,
 *   graceEndsAt, remindersSent: number[]}` (dates are Timestamps there).
 *
 * free ──activate──▶ active ──expiresAt──▶ grace ──graceEndsAt──▶ free
 *                     ▲  │ reminders 14/7/1 days before expiresAt
 *                     └──┘ extend
 */
export type SubscriptionStatus = "free" | "active" | "grace";

export interface Subscription {
  status: SubscriptionStatus;
  planId: string;
  billing: "monthly" | "annual" | null;
  startAt: Date | null;
  expiresAt: Date | null;
  graceEndsAt: Date | null;
  /** Reminder thresholds already sent for this period (days before expiry). */
  remindersSent: number[];
}

/** FR-100: emails and dashboard reminders this many days before expiry. */
export const REMINDER_DAYS = [14, 7, 1] as const;

/** FR-100: the grace period, configurable 0–30 (`config/platform.graceDays`). */
export const DEFAULT_GRACE_DAYS = 14;
export const MAX_GRACE_DAYS = 30;

const DAY_MS = 86_400_000;

/** `config/platform.graceDays`, clamped to 0–30; 14 when missing or invalid. */
export function graceDaysFrom(value: unknown): number {
  if (typeof value !== "number" || !Number.isInteger(value) || value < 0) return DEFAULT_GRACE_DAYS;
  return Math.min(value, MAX_GRACE_DAYS);
}

/** The Free subscription every restaurant starts with (FR-079: never expires). */
export function freeSubscription(startAt: Date | null = null): Subscription {
  return { status: "free", planId: "free", billing: null, startAt, expiresAt: null, graceEndsAt: null, remindersSent: [] };
}

function dateOf(v: unknown): Date | null {
  if (v instanceof Date) return v;
  if (v && typeof (v as { toDate?: unknown }).toDate === "function") return (v as { toDate(): Date }).toDate();
  return null;
}

/** Reads the stored map (Timestamps or Dates); anything odd reads as Free. */
export function subscriptionFrom(data: unknown, planId: unknown): Subscription {
  const d = (data && typeof data === "object" ? data : {}) as Record<string, unknown>;
  const status = d.status === "active" || d.status === "grace" ? d.status : "free";
  const billing = d.billing === "monthly" || d.billing === "annual" ? d.billing : null;
  const sent = Array.isArray(d.remindersSent) ? d.remindersSent.filter((n): n is number => typeof n === "number") : [];
  return {
    status,
    planId: typeof d.planId === "string" ? d.planId : typeof planId === "string" ? planId : "free",
    billing,
    startAt: dateOf(d.startAt),
    expiresAt: dateOf(d.expiresAt),
    graceEndsAt: dateOf(d.graceEndsAt),
    remindersSent: sent,
  };
}

export type DailyAction =
  | { kind: "none" }
  /** Send the reminder for `days` and record every threshold ≥ it (`markSent`). */
  | { kind: "remind"; days: number; daysLeft: number; markSent: number[] }
  /** Expired: grace until `graceEndsAt` (FR-100 step 2). */
  | { kind: "enterGrace"; graceEndsAt: Date }
  /** Grace over (or no grace configured): back to Free (FR-100 step 3). */
  | { kind: "downgrade" };

/**
 * What the daily job does for one subscription at `now`.
 *
 * - Active, before expiry: the smallest due reminder not yet sent (so a
 *   job that missed days sends one email, not three).
 * - Active, at or after expiry: grace, or a downgrade when grace is 0 days.
 * - Grace, at or after `graceEndsAt`: downgrade.
 * - Free: nothing (FR-079).
 */
export function dailyActionFor(sub: Subscription, now: Date, graceDays: number): DailyAction {
  if (sub.status === "grace") {
    if (!sub.graceEndsAt || now.getTime() >= sub.graceEndsAt.getTime()) return { kind: "downgrade" };
    return { kind: "none" };
  }
  if (sub.status !== "active" || !sub.expiresAt) return { kind: "none" };
  const msLeft = sub.expiresAt.getTime() - now.getTime();
  if (msLeft <= 0) {
    if (graceDays <= 0) return { kind: "downgrade" };
    return { kind: "enterGrace", graceEndsAt: new Date(sub.expiresAt.getTime() + graceDays * DAY_MS) };
  }
  const daysLeft = Math.ceil(msLeft / DAY_MS);
  const due = [...REMINDER_DAYS].sort((a, b) => a - b).find((d) => daysLeft <= d && !sub.remindersSent.includes(d));
  if (due === undefined) return { kind: "none" };
  return { kind: "remind", days: due, daysLeft, markSent: REMINDER_DAYS.filter((d) => d >= due) };
}

/** Days from `now` to `at`, rounded up (for banners and emails). */
export function daysUntil(at: Date, now: Date): number {
  return Math.max(0, Math.ceil((at.getTime() - now.getTime()) / DAY_MS));
}

/** Whether a paid plan is in force (active or in grace). */
export function isPaid(sub: Subscription): boolean {
  return sub.status === "active" || sub.status === "grace";
}
