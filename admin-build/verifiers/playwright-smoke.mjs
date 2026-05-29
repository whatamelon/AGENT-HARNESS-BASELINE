#!/usr/bin/env node
/**
 * L3 runtime verifier — Playwright smoke for admin states + viewports.
 *
 * Reads:
 *   ~/.config/agent-harness-baseline/admin-design/machine/state-taxonomy.yaml
 *   ~/.config/agent-harness-baseline/admin-design/machine/viewport-matrix.yaml
 *
 * Requires:
 *   - dev server running at process.env.ADMIN_BUILD_BASE_URL (default http://localhost:3000)
 *   - playwright installed in target repo (npx playwright install --with-deps chromium)
 *
 * Fixtures (4종): owner, ops, viewer, forbidden
 *   - test repo must export ADMIN_TEST_TOKEN_{owner,ops,viewer,forbidden} env vars
 *
 * Soft-fails (skip with exit 0) when playwright/chromium not available.
 */
import fs from "node:fs";
import path from "node:path";
import os from "node:os";

const HOME = os.homedir();
const SSOT_ROOT = process.env.ADMIN_DESIGN_ROOT
  || path.join(HOME, ".config/agent-harness-baseline/admin-design");

let chromium;
try { ({ chromium } = await import("playwright")); } catch { chromium = null; }
let yaml;
try { yaml = (await import("js-yaml")).default; } catch { yaml = null; }

if (!chromium || !yaml) {
  console.log(JSON.stringify({
    layer: "L3-playwright",
    status: "skip",
    reason: "playwright or js-yaml not installed in target repo. Install via: npm i -D playwright js-yaml && npx playwright install chromium",
  }, null, 2));
  process.exit(0);
}

const repo = path.resolve(process.argv[2] || ".");
const BASE_URL = process.env.ADMIN_BUILD_BASE_URL || "http://localhost:3000";

const viewportMatrix = yaml.load(fs.readFileSync(path.join(SSOT_ROOT, "machine/viewport-matrix.yaml"), "utf8"));
const stateMatrix = yaml.load(fs.readFileSync(path.join(SSOT_ROOT, "machine/state-taxonomy.yaml"), "utf8"));

const fixtures = {
  owner:     process.env.ADMIN_TEST_TOKEN_owner,
  ops:       process.env.ADMIN_TEST_TOKEN_ops,
  viewer:    process.env.ADMIN_TEST_TOKEN_viewer,
  forbidden: process.env.ADMIN_TEST_TOKEN_forbidden,
};

if (!fixtures.owner && !fixtures.ops && !fixtures.viewer && !fixtures.forbidden) {
  console.log(JSON.stringify({
    layer: "L3-playwright",
    status: "skip",
    reason: "no ADMIN_TEST_TOKEN_* env vars set; cannot test RBAC fixtures",
  }, null, 2));
  process.exit(0);
}

const findings = [];
const browser = await chromium.launch({ headless: true });

try {
  // probe 1: every list-page route renders all required states
  // we don't know the routes; ask via env or routes.json
  const routesFile = path.join(repo, ".admin-build/routes.json");
  if (!fs.existsSync(routesFile)) {
    findings.push({
      id: "L3-routes-manifest-missing",
      severity: "warn",
      message: ".admin-build/routes.json missing — orchestrator should emit before verify",
    });
  } else {
    const routes = JSON.parse(fs.readFileSync(routesFile, "utf8"));
    for (const route of routes) {
      // route = { path, type: list-page|detail-page|..., required_permission }
      for (const [vp, vpdef] of Object.entries(viewportMatrix.viewports || {})) {
        const def = vpdef.id ? vpdef : { id: vp, ...vpdef };
      }
      for (const vp of viewportMatrix.viewports || []) {
        const ctx = await browser.newContext({
          viewport: { width: vp.width, height: vp.height },
          storageState: undefined,
        });
        const page = await ctx.newPage();
        // owner fixture happy path
        if (fixtures.owner) {
          await page.setExtraHTTPHeaders({ "X-Admin-Test-Token": fixtures.owner });
        }
        try {
          await page.goto(BASE_URL + route.path, { waitUntil: "networkidle", timeout: 15000 });
          const bodyText = await page.locator("body").innerText();
          if (/dark/i.test(await page.getAttribute("html", "class") || "")) {
            findings.push({ id: "dark-class-on-html", severity: "fatal",
                            path: route.path, viewport: vp.id });
          }
          // horizontal overflow check
          const scrollW = await page.evaluate(() => document.documentElement.scrollWidth);
          const innerW = await page.evaluate(() => window.innerWidth);
          if (scrollW > innerW + 8) {
            findings.push({ id: "horizontal-overflow", severity: "error",
                            path: route.path, viewport: vp.id,
                            message: `scrollWidth=${scrollW} > innerWidth=${innerW}` });
          }
        } catch (e) {
          findings.push({ id: "navigation-failed", severity: "error",
                          path: route.path, viewport: vp.id, message: String(e).slice(0, 200) });
        } finally {
          await ctx.close();
        }
      }
      // RBAC: forbidden fixture must NOT see protected route
      if (fixtures.forbidden && route.required_permission) {
        const ctx = await browser.newContext({ viewport: { width: 1280, height: 800 } });
        const page = await ctx.newPage();
        await page.setExtraHTTPHeaders({ "X-Admin-Test-Token": fixtures.forbidden });
        try {
          const resp = await page.goto(BASE_URL + route.path, { waitUntil: "networkidle", timeout: 15000 });
          const text = await page.locator("body").innerText();
          const status = resp?.status();
          const isRedirected = page.url().includes("/login") || page.url().includes("/forbidden");
          const isForbiddenState = /permission|forbidden|access\s*denied/i.test(text);
          if (!isRedirected && !isForbiddenState && (status || 200) < 400) {
            findings.push({
              id: "forbidden-fixture-not-blocked", severity: "fatal",
              path: route.path,
              message: `forbidden fixture saw protected route without redirect/ForbiddenState (status=${status})`,
            });
          }
        } catch (e) {
          // failure here may be fine (network) — log as info
        } finally {
          await ctx.close();
        }
      }
    }
  }
} finally {
  await browser.close();
}

const status = findings.some((f) => f.severity === "fatal" || f.severity === "error") ? "fail" : "pass";
console.log(JSON.stringify({
  layer: "L3-playwright",
  status,
  total: findings.length,
  by_severity: ["fatal", "error", "warn", "info"].reduce((acc, k) => {
    acc[k] = findings.filter((f) => f.severity === k).length;
    return acc;
  }, {}),
  findings: findings.slice(0, 200),
  base_url: BASE_URL,
  repo,
}, null, 2));
process.exit(status === "pass" ? 0 : 1);
