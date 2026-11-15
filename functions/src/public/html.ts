/** HTML escaping for the server-rendered menu (architecture §3: every value is escaped). */

const ESCAPES: Record<string, string> = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  "\"": "&quot;",
  "'": "&#39;",
};

/** Escapes text for element content and quoted attribute values. */
export function esc(value: unknown): string {
  return String(value ?? "").replace(/[&<>"']/g, (c) => ESCAPES[c]);
}

/** Only `https:` URLs (and `tel:` / `mailto:` built here) go into links and images. */
export function safeUrl(url: unknown): string | null {
  if (typeof url !== "string") return null;
  try {
    const u = new URL(url);
    return u.protocol === "https:" || (u.protocol === "http:" && /^(localhost|127\.0\.0\.1)$/.test(u.hostname))
      ? u.toString()
      : null;
  } catch {
    return null;
  }
}

/** An id safe for `id=""` and `href="#…"` (Firestore ids are already [A-Za-z0-9_-]). */
export function anchorId(prefix: string, id: string): string {
  return `${prefix}-${id.replace(/[^A-Za-z0-9_-]/g, "_")}`;
}
