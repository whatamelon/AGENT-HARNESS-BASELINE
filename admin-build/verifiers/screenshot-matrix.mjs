#!/usr/bin/env node
/**
 * L4 visual matrix — capture viewport screenshots, write to .admin-build/runs/<latest>/screenshots/.
 *
 * Reads viewport-matrix.yaml + .admin-build/routes.json.
 * Soft-skip when playwright missing.
 */
import fs from "node:fs";
import path from "node:path";
import os from "node:os";

const HOME = os.homedir();
const SSOT_ROOT = process.env.ADMIN_DESIGN_ROOT
  || path.join(HOME, ".config/agent-harness-baseline/admin-design");

let chromium; try { ({ chromium } = await import("playwright")); } catch { chromium = null; }
let yaml; try { yaml = (await import("js-yaml")).default; } catch { yaml = null; }

const repo = path.resolve(process.argv[2] || ".");
const BASE_URL = process.env.ADMIN_BUILD_BASE_URL || "http://localhost:3000";

if (!chromium || !yaml) {
  console.log(JSON.stringify({ layer: "L4-screenshot", status: "skip",
                               reason: "playwright or js-yaml missing" }, null, 2));
  process.exit(0);
}

const matrixPath = path.join(SSOT_ROOT, "machine/viewport-matrix.yaml");
const routesFile = path.join(repo, ".admin-build/routes.json");
if (!fs.existsSync(matrixPath) || !fs.existsSync(routesFile)) {
  console.log(JSON.stringify({ layer: "L4-screenshot", status: "skip",
                               reason: "machine spec or routes.json missing" }, null, 2));
  process.exit(0);
}

const matrix = yaml.load(fs.readFileSync(matrixPath, "utf8"));
const routes = JSON.parse(fs.readFileSync(routesFile, "utf8"));

const runsRoot = path.join(repo, ".admin-build/runs");
const latestRun = fs.existsSync(runsRoot)
  ? fs.readdirSync(runsRoot).filter((n) => fs.statSync(path.join(runsRoot, n)).isDirectory()).sort().pop()
  : null;
if (!latestRun) {
  console.log(JSON.stringify({ layer: "L4-screenshot", status: "skip",
                               reason: "no .admin-build/runs/<ts>/ dir" }, null, 2));
  process.exit(0);
}
const shotsDir = path.join(runsRoot, latestRun, "screenshots");
fs.mkdirSync(shotsDir, { recursive: true });

const browser = await chromium.launch({ headless: true });
const shots = [];
try {
  const ownerToken = process.env.ADMIN_TEST_TOKEN_owner;
  for (const route of routes) {
    for (const vp of matrix.viewports || []) {
      const ctx = await browser.newContext({ viewport: { width: vp.width, height: vp.height } });
      const page = await ctx.newPage();
      if (ownerToken) await page.setExtraHTTPHeaders({ "X-Admin-Test-Token": ownerToken });
      try {
        await page.goto(BASE_URL + route.path, { waitUntil: "networkidle", timeout: 15000 });
        const safe = route.path.replace(/[^a-zA-Z0-9-_]/g, "_").replace(/^_/, "");
        const fn = `${safe || "root"}-${vp.id}.png`;
        await page.screenshot({ path: path.join(shotsDir, fn), fullPage: false });
        shots.push({ route: route.path, viewport: vp.id, file: fn });
      } catch (e) {
        shots.push({ route: route.path, viewport: vp.id, error: String(e).slice(0, 200) });
      } finally {
        await ctx.close();
      }
    }
  }
} finally {
  await browser.close();
}

console.log(JSON.stringify({
  layer: "L4-screenshot",
  status: "pass",
  total: shots.length,
  shots_dir: shotsDir,
  shots: shots.slice(0, 200),
  repo,
}, null, 2));
process.exit(0);
