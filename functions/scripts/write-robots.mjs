// Writes hosting/menu/robots.txt for a project (M07, architecture §3).
//
// The Functions Framework answers /robots.txt itself (an empty 404) before
// renderMenu runs, so robots.txt is a static Hosting file. Its Sitemap line
// needs the absolute menu origin, which differs per project.
//
// Usage: node functions/scripts/write-robots.mjs [projectId]
// (Hosting predeploy uses $GCLOUD_PROJECT; the npm test scripts pass demo-eazysuvai.)
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

// Keep in step with MENU_ORIGINS in src/public/serve.ts (public.test.ts compares them).
export const ORIGINS = {
  "eazysuvai-prod": "https://menu.eazysuvai.com",
  "eazy-suvai-dev": "https://eazy-suvai-dev-menu.web.app",
  "demo-eazysuvai": "http://127.0.0.1:5000",
};
const DEFAULT_ORIGIN = "https://menu.eazysuvai.com";

const here = path.dirname(fileURLToPath(import.meta.url));

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const project = process.argv[2] || process.env.GCLOUD_PROJECT || "";
  const base = (process.env.MENU_BASE_URL || ORIGINS[project] || DEFAULT_ORIGIN).replace(/\/$/, "");
  const robots = `User-agent: *\nAllow: /\nDisallow: /q/\n\nSitemap: ${base}/sitemap.xml\n`;
  fs.writeFileSync(path.resolve(here, "../../hosting/menu/robots.txt"), robots);
  console.log(`robots.txt for ${project || "default"}: Sitemap ${base}/sitemap.xml`);
}
