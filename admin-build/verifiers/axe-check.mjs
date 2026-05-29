#!/usr/bin/env node
/**
 * L4 a11y verifier via axe-core + Playwright.
 *
 * Requires: playwright, @axe-core/playwright (target repo dev deps).
 * Targets routes from .admin-build/routes.json.
 * Soft-skip when deps missing.
 */
import fs from "node:fs";
import path from "node:path";

let chromium;
try { ({ chromium } = await import("playwright")); } catch { chromium = null; }
let AxeBuilder;
try { ({ default: AxeBuilder } = await import("@axe-core/playwright")); } catch { AxeBuilder = null; }

const repo = path.resolve(process.argv[2] || ".");
const BASE_URL = process.env.ADMIN_BUILD_BASE_URL || "http://localhost:3000";

if (!chromium || !AxeBuilder) {
  console.log(JSON.stringify({
    layer: "L4-axe", status: "skip",
    reason: "playwright or @axe-core/playwright missing in repo",
  }, null, 2));
  process.exit(0);
}

const routesFile = path.join(repo, ".admin-build/routes.json");
if (!fs.existsSync(routesFile)) {
  console.log(JSON.stringify({
    layer: "L4-axe", status: "skip",
    reason: ".admin-build/routes.json missing",
  }, null, 2));
  process.exit(0);
}

const routes = JSON.parse(fs.readFileSync(routesFile, "utf8"));
const findings = [];
const browser = await chromium.launch({ headless: true });
try {
  for (const route of routes) {
    const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
    const page = await ctx.newPage();
    const ownerToken = process.env.ADMIN_TEST_TOKEN_owner;
    if (ownerToken) {
      await page.setExtraHTTPHeaders({ "X-Admin-Test-Token": ownerToken });
    }
    try {
      await page.goto(BASE_URL + route.path, { waitUntil: "networkidle", timeout: 15000 });
      const results = await new AxeBuilder({ page })
        .withTags(["wcag2a", "wcag2aa", "wcag21aa"])
        .analyze();
      for (const v of results.violations || []) {
        findings.push({
          id: v.id,
          severity: v.impact === "critical" ? "error" : (v.impact === "serious" ? "error" : "warn"),
          path: route.path,
          message: v.help,
          help_url: v.helpUrl,
          nodes: (v.nodes || []).length,
        });
      }
    } catch (e) {
      findings.push({ id: "axe-page-error", severity: "warn", path: route.path,
                      message: String(e).slice(0, 200) });
    } finally {
      await ctx.close();
    }
  }
} finally {
  await browser.close();
}

const status = findings.some((f) => f.severity === "error" || f.severity === "fatal") ? "fail" : "pass";
console.log(JSON.stringify({
  layer: "L4-axe",
  status,
  total: findings.length,
  findings: findings.slice(0, 200),
  truncated: findings.length > 200,
  repo,
}, null, 2));
process.exit(status === "pass" ? 0 : 1);
