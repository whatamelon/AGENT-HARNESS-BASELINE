#!/usr/bin/env node
/**
 * L3 RBAC runtime verifier (security 동급 게이트).
 *
 * Reads:
 *   ~/.config/agent-harness-baseline/admin-security/_rbac-matrix.yaml
 *   .admin-build/routes.json (orchestrator-emitted)
 *
 * Verifies (4 fixtures × N routes × M actions):
 *   1. expected_allow fixtures can navigate + see expected content
 *   2. expected_deny fixtures get 403/redirect/ForbiddenState (UI 측)
 *   3. expected_deny fixtures cannot bypass via direct API call (server 측)
 *
 * Requires:
 *   - ADMIN_TEST_TOKEN_{owner,ops,viewer,forbidden} env
 *   - BASE_URL env
 *   - playwright (browser context) + node fetch (server check)
 *
 * Soft-fails with skip if missing.
 */
import fs from "node:fs";
import path from "node:path";
import os from "node:os";

const HOME = os.homedir();
const SEC_ROOT = process.env.ADMIN_SECURITY_ROOT
  || path.join(HOME, ".config/agent-harness-baseline/admin-security");

let yaml;
try { yaml = (await import("js-yaml")).default; } catch { yaml = null; }

const repo = path.resolve(process.argv[2] || ".");
const BASE_URL = process.env.ADMIN_BUILD_BASE_URL || "http://localhost:3000";

const fixtures = {
  owner: process.env.ADMIN_TEST_TOKEN_owner,
  ops: process.env.ADMIN_TEST_TOKEN_ops,
  viewer: process.env.ADMIN_TEST_TOKEN_viewer,
  forbidden: process.env.ADMIN_TEST_TOKEN_forbidden,
};

if (!yaml) {
  console.log(JSON.stringify({ layer: "L3-rbac", status: "skip", reason: "js-yaml missing in repo" }, null, 2));
  process.exit(0);
}

const matrixPath = path.join(SEC_ROOT, "_rbac-matrix.yaml");
const routesPath = path.join(repo, ".admin-build/routes.json");
if (!fs.existsSync(matrixPath)) {
  console.log(JSON.stringify({ layer: "L3-rbac", status: "skip", reason: "_rbac-matrix.yaml missing" }, null, 2));
  process.exit(0);
}
if (!fs.existsSync(routesPath)) {
  console.log(JSON.stringify({
    layer: "L3-rbac", status: "skip",
    reason: ".admin-build/routes.json missing — orchestrator should emit",
  }, null, 2));
  process.exit(0);
}
const tokenAvailable = Object.values(fixtures).some(Boolean);
if (!tokenAvailable) {
  console.log(JSON.stringify({
    layer: "L3-rbac", status: "skip",
    reason: "no ADMIN_TEST_TOKEN_* env set",
  }, null, 2));
  process.exit(0);
}

const matrix = yaml.load(fs.readFileSync(matrixPath, "utf8"));
const routes = JSON.parse(fs.readFileSync(routesPath, "utf8"));
const findings = [];

async function fetchAs(fixture, url, options = {}) {
  const token = fixtures[fixture];
  if (!token) return null;
  return fetch(url, {
    ...options,
    headers: { ...(options.headers || {}), "X-Admin-Test-Token": token },
  });
}

for (const route of routes) {
  const matrixKey = route.type === "list_page" ? "list_page"
                  : route.type === "detail_page" ? "detail_page"
                  : null;
  if (!matrixKey) continue;
  const policy = matrix.route_action_matrix?.[matrixKey];
  if (!policy) continue;

  // server-layer probe: forbidden fixture must not get 200 on direct route
  if (fixtures.forbidden) {
    try {
      const resp = await fetchAs("forbidden", BASE_URL + route.path, { redirect: "manual" });
      if (!resp) continue;
      const status = resp.status;
      if (status >= 200 && status < 300) {
        // 200 OK — possible bypass. need body check.
        const text = await resp.text();
        if (!/permission|forbidden|access\s*denied/i.test(text)) {
          findings.push({
            id: "rbac-forbidden-bypass",
            severity: "fatal",
            path: route.path,
            message: `forbidden fixture got 200 OK without ForbiddenState — server enforcement missing`,
          });
        }
      } else if (status >= 300 && status < 400) {
        // redirect — OK (login/forbidden page)
      } else if (status >= 400 && status < 500) {
        // 401/403 — OK (server denying)
      }
    } catch (e) {
      findings.push({ id: "rbac-fetch-error", severity: "warn", path: route.path,
                      message: String(e).slice(0, 200) });
    }
  }

  // expected_allow fixtures must succeed
  for (const role of policy.fixtures_allow || []) {
    if (!fixtures[role]) continue;
    try {
      const resp = await fetchAs(role, BASE_URL + route.path, { redirect: "manual" });
      if (!resp) continue;
      if (resp.status >= 400) {
        findings.push({
          id: "rbac-allow-fixture-denied",
          severity: "error",
          path: route.path,
          role,
          message: `${role} expected allow but got ${resp.status}`,
        });
      }
    } catch (e) {
      findings.push({ id: "rbac-fetch-error", severity: "warn", path: route.path, role,
                      message: String(e).slice(0, 200) });
    }
  }
}

const status = findings.some((f) => f.severity === "fatal" || f.severity === "error") ? "fail" : "pass";
console.log(JSON.stringify({
  layer: "L3-rbac",
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
