/**
 * The public menu's non-live pages (FR-046, FR-099). They use the
 * EazySuvai brand colours (the restaurant's theme belongs to a published
 * version, which these states don't have), carry `noindex`, and show the
 * restaurant's name only where FR-099 allows it.
 *
 * | Kind | HTTP | Text |
 * | --- | --- | --- |
 * | `coming-soon` | 404 | "Menu coming soon" + name |
 * | `unavailable` | 503 | "Menu temporarily unavailable" + name only |
 * | `gone` | 410 | "Menu no longer available" |
 * | `not-found` | 404 | generic |
 * | `error` | 500 | "Something went wrong" + "Try again" |
 */
import { esc } from "./html";
import { BASE_CSS } from "./render-menu";
import { fill, menuText } from "./text";

export type StateKind = "coming-soon" | "unavailable" | "gone" | "not-found" | "error";

export const STATE_STATUS: Record<StateKind, number> = {
  "coming-soon": 404,
  "unavailable": 503,
  "gone": 410,
  "not-found": 404,
  "error": 500,
};

/** Brand colours (AA: charcoal and orangeText on cream, BrandColors in core). */
const BRAND_VARS =
  "--es-background:#FFF8EE;--es-surface:#FFFFFF;--es-text:#2B2B2B;--es-muted-text:#5C5C5C;--es-accent:#A8550A;--es-border:#E8DCCB";

const CSS = `${BASE_CSS}
main{min-height:100vh;display:flex;align-items:center;justify-content:center;text-align:center;padding:32px 16px}
.card{max-width:480px}
.mark{width:56px;height:56px;margin:0 auto 16px;border-radius:16px;background:var(--es-accent);color:#fff;display:flex;align-items:center;justify-content:center;font-size:28px;font-weight:700}
.name{margin:0 0 8px;color:var(--es-muted-text);font-weight:600}
p{margin:12px 0 0;color:var(--es-muted-text)}
.btn{display:inline-flex;align-items:center;min-height:48px;padding:0 24px;margin-top:20px;border-radius:999px;background:var(--es-accent);color:#fff;text-decoration:none;font-weight:600}
footer{position:fixed;bottom:12px;left:0;right:0;text-align:center;font-size:.85rem;color:var(--es-muted-text)}`;

/**
 * Renders a state page.
 *
 * @param kind Which state.
 * @param o `name`: the restaurant (coming soon and unavailable only);
 *   `locale`: for the text; `retryUrl`: the error page's "Try again" link.
 * @return A complete HTML document.
 */
export function renderStatePage(kind: StateKind, o: { name?: string; locale?: string; retryUrl?: string } = {}): string {
  const t = menuText(o.locale).states;
  const name = o.name?.trim() || "";
  const showName = name !== "" && (kind === "coming-soon" || kind === "unavailable");
  const [title, body] = {
    "coming-soon": [t.comingSoonTitle, fill(t.comingSoonBody, { name: name || t.someRestaurant })],
    "unavailable": [t.unavailableTitle, fill(t.unavailableBody, { name: name || t.someRestaurantLower })],
    "gone": [t.goneTitle, t.goneBody],
    "not-found": [t.notFoundTitle, t.notFoundBody],
    "error": [t.errorTitle, t.errorBody],
  }[kind];
  const pageTitle = showName ? `${name} – ${title}` : `${title} | EazySuvai`;
  const retry = kind === "error" && o.retryUrl ? `<a class="btn" href="${esc(o.retryUrl)}">${esc(t.retry)}</a>` : "";
  return `<!DOCTYPE html>
<html lang="${esc(o.locale ?? "en")}" dir="ltr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>${esc(pageTitle)}</title>
<style>:root{${BRAND_VARS}}${CSS}</style>
</head>
<body class="state state-${kind}">
<main>
<div class="card">
<div class="mark" aria-hidden="true">e</div>
${showName ? `<p class="name">${esc(name)}</p>` : ""}
<h1>${esc(title)}</h1>
<p>${esc(body)}</p>
${retry}
</div>
</main>
<footer>EazySuvai</footer>
</body>
</html>`;
}
