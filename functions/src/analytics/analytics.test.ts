import { BEACON_SCRIPT, BODY_SCRIPT } from "../public/client-script";
import { RateLimiter, dayKeyIn, isBotAgent, parseEvent } from "./collect";

const CHROME_ANDROID =
  "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36";
const SAFARI_IPHONE =
  "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1";

describe("parseEvent", () => {
  it("accepts the three event shapes", () => {
    expect(parseEvent(JSON.stringify({ type: "view", slug: "spice-garden", src: "qr" }))).toEqual({ type: "view", slug: "spice-garden", src: "qr" });
    expect(parseEvent(JSON.stringify({ type: "view", slug: "spice-garden" }))).toEqual({ type: "view", slug: "spice-garden", src: "direct" });
    expect(parseEvent(JSON.stringify({ type: "cat", slug: "a1b", src: "direct", id: "tiffin" }))?.id).toBe("tiffin");
    expect(parseEvent(JSON.stringify({ type: "item", slug: "a1b", src: "direct", id: "i_1-x" }))?.type).toBe("item");
  });

  it.each([
    ["not JSON", "{oops"],
    ["empty", ""],
    ["unknown type", JSON.stringify({ type: "click", slug: "abc" })],
    ["bad slug", JSON.stringify({ type: "view", slug: "../etc" })],
    ["bad src", JSON.stringify({ type: "view", slug: "abc", src: "email" })],
    ["cat without id", JSON.stringify({ type: "cat", slug: "abc" })],
    ["view with id", JSON.stringify({ type: "view", slug: "abc", id: "x" })],
    ["id with a dot (field path)", JSON.stringify({ type: "item", slug: "abc", id: "a.b" })],
    ["extra keys (a session id must not be sent)", JSON.stringify({ type: "view", slug: "abc", sid: "123" })],
    ["over 1 KB", JSON.stringify({ type: "view", slug: "abc", pad: "x".repeat(2000) })],
    ["an array", "[]"],
  ])("rejects %s", (_label, body) => {
    expect(parseEvent(body)).toBeNull();
  });
});

describe("isBotAgent (FR-073)", () => {
  it.each([
    "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
    "Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)",
    "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)",
    "WhatsApp/2.23.20.0",
    "curl/8.4.0",
    "python-requests/2.31.0",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/120.0.0.0 Safari/537.36",
    "",
    "short",
  ])("drops %s", (ua) => {
    expect(isBotAgent(ua)).toBe(true);
  });

  it("keeps real browsers", () => {
    expect(isBotAgent(CHROME_ANDROID)).toBe(false);
    expect(isBotAgent(SAFARI_IPHONE)).toBe(false);
    expect(isBotAgent(undefined)).toBe(true);
  });
});

describe("dayKeyIn (FR-075: the restaurant's time zone)", () => {
  it("puts the same instant on different days by zone", () => {
    const at = new Date("2026-11-15T19:00:00Z"); // 00:30 on the 16th in India
    expect(dayKeyIn(at, "Asia/Kolkata")).toBe("2026-11-16");
    expect(dayKeyIn(at, "Asia/Kuwait")).toBe("2026-11-15"); // 22:00
    expect(dayKeyIn(at, "America/New_York")).toBe("2026-11-15");
    expect(dayKeyIn(at, "Not/AZone")).toBe("2026-11-15");
  });

  it("handles the boundary minute", () => {
    expect(dayKeyIn(new Date("2026-11-15T18:29:59Z"), "Asia/Kolkata")).toBe("2026-11-15");
    expect(dayKeyIn(new Date("2026-11-15T18:30:00Z"), "Asia/Kolkata")).toBe("2026-11-16");
  });
});

describe("RateLimiter", () => {
  it("allows up to the limit per key per window", () => {
    const l = new RateLimiter(3, 60_000);
    expect([1, 2, 3, 4].map(() => l.allow("1.2.3.4", 1000))).toEqual([true, true, true, false]);
    expect(l.allow("5.6.7.8", 1000)).toBe(true);
    expect(l.allow("1.2.3.4", 61_001)).toBe(true);
  });
});

describe("beacon script", () => {
  it("is under 1 KB, cookieless, and only in the page script", () => {
    expect(Buffer.byteLength(BEACON_SCRIPT)).toBeLessThan(1024);
    expect(BODY_SCRIPT).toContain(BEACON_SCRIPT);
    expect(BODY_SCRIPT).not.toMatch(/cookie|localStorage|https?:\/\//);
    expect(BEACON_SCRIPT).toContain("sessionStorage");
    expect(BEACON_SCRIPT).toContain("18e5"); // 30 minutes
  });

  it("sends a view at most once per 30 minutes per session", () => {
    const sent: string[] = [];
    const store = new Map<string, string>();
    let now = 1_000_000;
    const run = () => {
      const w = { sessionStorage: { getItem: (k: string) => store.get(k) ?? null, setItem: (k: string, v: string) => store.set(k, v) } };
      const ds = { beacon: "/e", slug: "spice-garden" };
      const navigator = { sendBeacon: (_u: string, b: { text: string }) => sent.push(b.text) };
      class FakeBlob {
        text: string;
        constructor(parts: string[]) {
          this.text = parts.join("");
        }
      }
      const DateNow = { now: () => now };
      // The beacon reads `w`, `ds`, `src`, `navigator`, `Blob`, `Date`.
      new Function("w", "ds", "src", "navigator", "Blob", "Date", `${BEACON_SCRIPT};track("view",{});track("cat",{id:"c1"})`)(
        w, ds, "qr", navigator, FakeBlob, DateNow,
      );
    };
    run();
    now += 10 * 60_000; // reload after 10 minutes
    run();
    now += 25 * 60_000; // 35 minutes after the first view
    run();
    const views = sent.map((s) => JSON.parse(s)).filter((e) => e.type === "view");
    const cats = sent.map((s) => JSON.parse(s)).filter((e) => e.type === "cat");
    expect(views).toHaveLength(2);
    expect(cats).toHaveLength(3);
    expect(views[0]).toEqual({ type: "view", slug: "spice-garden", src: "qr" });
    expect(cats[0]).toEqual({ type: "cat", slug: "spice-garden", src: "qr", id: "c1" });
  });
});
