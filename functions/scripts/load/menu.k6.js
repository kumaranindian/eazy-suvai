// k6 load test for a real project (M13, FRD §7.3). Run against DEV only
// unless production is agreed:
//   k6 run -e BASE=https://eazy-suvai-dev-menu.web.app -e SLUGS=spice-garden,dosa-corner scripts/load/menu.k6.js
// 200 requests/s for 5 minutes, 90 % menu pages and 10 % view beacons.
// Thresholds: < 1 % errors, p95 < 800 ms (most answers come from the CDN).
/* global __ENV -- k6 runtime global */
import http from "k6/http";
import { check } from "k6";

const BASE = __ENV.BASE;
const SLUGS = (__ENV.SLUGS || "").split(",").filter(Boolean);

export const options = {
  scenarios: {
    peak: { executor: "constant-arrival-rate", rate: 200, timeUnit: "1s", duration: "5m", preAllocatedVUs: 100, maxVUs: 400 },
  },
  thresholds: { http_req_failed: ["rate<0.01"], http_req_duration: ["p(95)<800"] },
};

export default function () {
  const slug = SLUGS[Math.floor(Math.random() * SLUGS.length)];
  if (Math.random() < 0.1) {
    http.post(`${BASE}/e`, JSON.stringify({ type: "view", slug, src: "direct" }), { headers: { "content-type": "text/plain" } });
    return;
  }
  const r = http.get(`${BASE}/${slug}`);
  check(r, {
    "status 200": (x) => x.status === 200,
    "CDN cacheable": (x) => /s-maxage=\d+/.test(x.headers["Cache-Control"] || ""),
  });
}
