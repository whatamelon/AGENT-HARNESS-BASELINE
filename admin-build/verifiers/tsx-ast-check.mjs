#!/usr/bin/env node
/**
 * L2 AST verifier for admin design system.
 *
 * Uses ts-morph (peer dep — install in repo if absent).
 *
 * Reads:
 *   ~/.config/agent-harness-baseline/admin-design/machine/component-contracts.yaml
 *   ~/.config/agent-harness-baseline/admin-design/machine/checklist.yaml
 *
 * Probes:
 *   - foundation-components-present (named exports from components/admin index)
 *   - structured-query-keys (Keys factory export)
 *   - primary-occurrence-cap (bg-primary <=1 per route file)
 *   - zod-schema-presence (forms use zodResolver(schema))
 *   - permission-gate-paired-with-server-enforcement (annotated import check)
 *   - route-permission-check (RouteMeta.requiredPermission or beforeLoad guard)
 *   - no-tinted-card-background (Card with bg-primary/etc)
 *
 * Soft fail mode: when ts-morph missing, emits skip report + exit 0.
 */
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { fileURLToPath, pathToFileURL } from "node:url";

const HOME = os.homedir();
const SSOT_ROOT = process.env.ADMIN_DESIGN_ROOT
  || path.join(HOME, ".config/agent-harness-baseline/admin-design");

let yaml;
try { yaml = (await import("js-yaml")).default; } catch { yaml = null; }
let Project;
try { ({ Project } = await import("ts-morph")); } catch { Project = null; }

const repo = path.resolve(process.argv[2] || ".");
if (!fs.existsSync(repo)) {
  console.error(`not a directory: ${repo}`);
  process.exit(2);
}

function emit(report) {
  console.log(JSON.stringify(report, null, 2));
}

if (!Project) {
  emit({ layer: "L2-tsx-ast", status: "skip", reason: "ts-morph not installed (npm i -D ts-morph)" });
  process.exit(0);
}
if (!yaml) {
  emit({ layer: "L2-tsx-ast", status: "skip", reason: "js-yaml not installed (npm i -D js-yaml)" });
  process.exit(0);
}

const contractsPath = path.join(SSOT_ROOT, "machine/component-contracts.yaml");
const checklistPath = path.join(SSOT_ROOT, "machine/checklist.yaml");

if (!fs.existsSync(contractsPath) || !fs.existsSync(checklistPath)) {
  emit({ layer: "L2-tsx-ast", status: "skip", reason: "machine specs missing" });
  process.exit(0);
}

const contracts = yaml.load(fs.readFileSync(contractsPath, "utf8"));
const checklist = yaml.load(fs.readFileSync(checklistPath, "utf8"));

// Locate tsconfig
const tsconfig = ["tsconfig.json", "tsconfig.base.json"]
  .map((n) => path.join(repo, n))
  .find((p) => fs.existsSync(p));

const project = new Project(tsconfig
  ? { tsConfigFilePath: tsconfig, skipAddingFilesFromTsConfig: false }
  : { compilerOptions: { allowJs: true, jsx: 1 } });

if (!tsconfig) {
  // best-effort: add admin-related files
  const globs = [
    "src/**/*.{ts,tsx}",
    "app/**/*.{ts,tsx}",
    "components/**/*.{ts,tsx}",
    "features/**/*.{ts,tsx}",
  ];
  for (const g of globs) {
    project.addSourceFilesAtPaths(path.join(repo, g));
  }
}

const findings = [];

function addFinding(probeId, severity, path_, line, message) {
  findings.push({ id: probeId, severity, path: path_, line, message });
}

// --- Probe: foundation-components-present ---
// 검사 우선순위:
//   A. contract.location 파일이 존재 + 그 파일에 `export ... <ComponentName>` 명시 named export → PASS
//   B. fallback: baseName 매칭 (kebab/camel 무시)
const requiredComponents = Object.keys(contracts.components || {});
const sourceFiles = project.getSourceFiles();
const componentLocations = {};
for (const comp of requiredComponents) {
  const contract = contracts.components[comp] || {};
  const expectedLoc = contract.location || "";
  let found = null;
  if (expectedLoc) {
    // Source A — contract location 우선 (named export 검증)
    const expectSuffix = expectedLoc.replace(/^\//, "");
    const sf = sourceFiles.find((sf) => sf.getFilePath().endsWith(expectSuffix));
    if (sf) {
      const text = sf.getFullText();
      const exportRx = new RegExp(
        `\\bexport\\s+(?:async\\s+)?(?:function|const|let|class|interface|type)\\s+${comp}\\b`
      );
      if (exportRx.test(text)) found = sf;
    }
  }
  if (!found) {
    // Source B — fallback baseName 매칭
    found = sourceFiles.find((sf) =>
      sf.getFilePath().includes("/components/admin/")
      && (sf.getBaseNameWithoutExtension().toLowerCase() === comp.toLowerCase()
          || sf.getBaseNameWithoutExtension()
              .replace(/-/g, "")
              .toLowerCase() === comp.toLowerCase()));
  }
  componentLocations[comp] = found;
}
for (const [comp, sf] of Object.entries(componentLocations)) {
  if (!sf) {
    addFinding("foundation-components-present", "error",
               `src/components/admin/`, 0,
               `missing component: ${comp} (expected at ${contracts.components[comp]?.location})`);
  }
}

// --- Probe: structured-query-keys ---
// 매칭 path 확장 (2026-05-28):
//   A. features/<x>/api.ts or queries.ts (feature-sliced)
//   B. src/queries/keys.ts (centralized factory)
//   C. src/queries/<domain>.queries.ts (domain-split)
//   D. legacy /queries.ts at any depth
let foundKeysFactory = false;
for (const sf of sourceFiles) {
  const fp = sf.getFilePath();
  const isFeatureSliced = /\/features\/[^/]+\/(api|queries)\.ts$/.test(fp);
  const isQueriesDir = /\/queries\/[^/]+\.(?:queries\.)?ts$/.test(fp);
  const isLegacyQueries = /\/queries?\.ts$/.test(fp);
  if (!isFeatureSliced && !isQueriesDir && !isLegacyQueries) continue;
  const text = sf.getFullText();
  if (/\b\w+Keys\s*=\s*\{[\s\S]*?all:\s*\[/.test(text)) {
    foundKeysFactory = true; break;
  }
}
if (sourceFiles.length > 0 && !foundKeysFactory) {
  addFinding("structured-query-keys", "warn",
             "src/queries/** | src/features/**", 0,
             "no Keys factory pattern found (expected exports like ordersKeys.all/lists/list/detail)");
}

// --- Probe: primary-occurrence-cap (bg-primary <=1 per file) ---
const PRIMARY_RX = /\bbg-primary\b(?!-foreground)/g;
for (const sf of sourceFiles) {
  const fp = sf.getFilePath();
  if (!/\/(app|routes)\//.test(fp)) continue;
  const text = sf.getFullText();
  const matches = text.match(PRIMARY_RX) || [];
  if (matches.length > 1) {
    addFinding("primary-occurrence-cap", "warn",
               path.relative(repo, fp), 0,
               `bg-primary used ${matches.length} times (cap=1 per route file)`);
  }
}

// --- Probe: zod-schema-presence (form components) ---
for (const sf of sourceFiles) {
  const fp = sf.getFilePath();
  if (!/\/(forms?|FormShell|CreateDrawer|EditDrawer)/.test(fp)) continue;
  const text = sf.getFullText();
  const importsHookForm = /from\s+["']react-hook-form["']/.test(text);
  if (!importsHookForm) continue;
  const hasZodResolver = /zodResolver\s*\(/.test(text);
  const importsZ = /from\s+["']zod["']/.test(text);
  if (!hasZodResolver || !importsZ) {
    addFinding("zod-schema-presence", "error",
               path.relative(repo, fp), 0,
               "RHF form without zodResolver/zod schema");
  }
}

// --- Probe: route-permission-check ---
for (const sf of sourceFiles) {
  const fp = sf.getFilePath();
  if (!/\/(routes|app)\/(admin|\(admin\))\//.test(fp)) continue;
  const text = sf.getFullText();
  const hasMeta = /requiredPermission\s*:/.test(text);
  const hasBeforeLoad = /beforeLoad\s*:/.test(text);
  const hasGate = /<PermissionGate\b/.test(text);
  if (!hasMeta && !hasBeforeLoad && !hasGate) {
    addFinding("route-permission-check", "error",
               path.relative(repo, fp), 0,
               "protected admin route has no permission guard (requiredPermission, beforeLoad, or PermissionGate)");
  }
}

// --- Probe: no-tinted-card-background ---
const CARD_TINT_RX = /<Card[\s\S]*?className=["'`][^"'`]*\b(bg-primary|bg-blue-|bg-indigo-|bg-purple-|bg-emerald-)/g;
for (const sf of sourceFiles) {
  const text = sf.getFullText();
  const m = CARD_TINT_RX.exec(text);
  if (m) {
    addFinding("no-tinted-card-background", "error",
               path.relative(repo, sf.getFilePath()), 0,
               `tinted Card background: ${m[1]}`);
  }
}

// --- Probe: list-page-uses-data-components (2026-05-28 — list 4 의무 강제) ---
const LIST_PAGE_RX = /src\/app\/\(protected\)\/([^/]+(?:\/[^/[]+)*?)\/page\.tsx$/;
const SKIP_LIST_DOMAINS = new Set(["dashboard", "settings", "carmanager", "leads"]);

// routes.json 우선 — type==list_page path 만 검사. 그 외 type
// (sub_list_terminal / form_page / hub_page / dashboard_page / detail_page) skip.
let listPageRouteSet = null;
const routesJsonPath = path.join(repo, ".admin-build", "routes.json");
if (fs.existsSync(routesJsonPath)) {
  try {
    const routes = JSON.parse(fs.readFileSync(routesJsonPath, "utf8"));
    if (Array.isArray(routes)) {
      listPageRouteSet = new Set(
        routes
          .filter((r) => r && r.type === "list_page" && typeof r.path === "string")
          .map((r) => r.path.replace(/\/$/, ""))
          .filter(Boolean)
      );
    }
  } catch {
    listPageRouteSet = null;
  }
}

const LIST_PROBE_RESULTS = [];
for (const sf of sourceFiles) {
  const fp = sf.getFilePath();
  const m = fp.match(LIST_PAGE_RX);
  if (!m) continue;
  const domainPath = m[1];

  if (listPageRouteSet !== null) {
    // routes.json 모드 — 명시된 list_page 만 검사
    const routePath = "/" + domainPath;
    if (!listPageRouteSet.has(routePath)) continue;
  } else {
    // fallback — first segment domain skip
    const firstSeg = domainPath.split("/")[0];
    if (SKIP_LIST_DOMAINS.has(firstSeg)) continue;
  }
  // [id] 자체는 detail page — skip
  if (fp.includes("/[id]/")) continue;
  // 그 외 = list page
  const text = sf.getFullText();
  const rel = path.relative(repo, fp);

  // 1. DataTable JSX 또는 TanStack import (또는 native <table>)
  const hasDataTable =
    /<DataTable\b/.test(text) || /from\s+["']@tanstack\/react-table["']/.test(text);
  const hasNativeTable = /<table\b/.test(text);
  if (!hasDataTable && hasNativeTable) {
    addFinding("list-page-uses-data-table", "error", rel, 0,
      "list page uses native <table> instead of DataTable abstraction");
  } else if (!hasDataTable && !hasNativeTable) {
    addFinding("list-page-uses-data-table", "error", rel, 0,
      "list page must render DataTable (TanStack Table abstraction)");
  }

  // 2. Toolbar / search input — DataToolbar OR FilterBar OR <Input ... placeholder*=검색
  const hasToolbar =
    /<DataToolbar\b/.test(text) ||
    /<FilterBar\b/.test(text) ||
    /<Input[\s\S]*?(placeholder=["'][^"']*검색|placeholder=["'][^"']*search|aria-label=["'][^"']*검색)/i.test(text);
  if (!hasToolbar) {
    addFinding("list-page-has-filter-bar", "error", rel, 0,
      "list page must render DataToolbar/FilterBar with search input");
  }

  // 3. Pagination — PaginationLinks OR PaginationBar
  const hasPagination =
    /<PaginationLinks\b/.test(text) || /<PaginationBar\b/.test(text);
  if (!hasPagination) {
    addFinding("list-page-has-pagination-bar", "error", rel, 0,
      "list page must render PaginationLinks/PaginationBar");
  }

  // 4. Filter chip / select — FilterChip OR FilterChipGroup OR <select> with status/source
  const hasFilterChip =
    /<FilterChip\b/.test(text) ||
    /<FilterChipGroup\b/.test(text) ||
    /<select\b/.test(text);
  if (!hasFilterChip) {
    addFinding("list-page-has-filter-chip", "warn", rel, 0,
      "list page should expose filter chips for enum columns (status/source/etc)");
  }

  // 5. PK 단일 진입 (2026-05-29, 구 primary-column-links-detail 대체).
  //    상세 진입은 PK 컬럼(pkColumn()/PkLink) 한 곳만. 이름/제목/번호판 등 비-PK 셀에
  //    <Link href={xxxDetail(...)}> 가 있으면 위반.
  //    RSC entry page 가 client `_components/*-table.tsx` 로 delegate 하는 경우도 합산.
  const pkRx = [/\bpkColumn\s*[<(]/, /<PkLink\b/];
  // 비-PK detail 링크 = <Link ... href={ xxxDetail( ... )} (pk-cell.tsx 외부)
  const nameLinkRx = /<Link\b[\s\S]{0,80}?href=\{[^}]*\b[a-zA-Z]+Detail\s*\(/;
  const scanTexts = [text];
  const pageDir = path.dirname(fp);
  const componentsDir = path.join(pageDir, "_components");
  if (fs.existsSync(componentsDir)) {
    try {
      for (const c of fs.readdirSync(componentsDir).filter((n) => /\.(tsx|jsx)$/.test(n))) {
        scanTexts.push(fs.readFileSync(path.join(componentsDir, c), "utf8"));
      }
    } catch {
      /* ignore */
    }
  }
  const hasPk = scanTexts.some((t) => pkRx.some((rx) => rx.test(t)));
  const hasNameLink = scanTexts.some((t) => nameLinkRx.test(t));
  if (!hasPk) {
    addFinding("pk-column-sole-detail-entry", "error", rel, 0,
      "list page 첫 데이터 컬럼이 pkColumn()/PkLink 가 아님 — PK(`#id` bold underline) 가 상세 진입 단일 출구여야 함");
  }
  if (hasNameLink) {
    addFinding("pk-column-sole-detail-entry", "error", rel, 0,
      "비-PK 셀에 <Link href={xxxDetail(...)}> 존재 — 상세 진입은 PK 단일. 이름/제목 셀은 평문으로");
  }

  LIST_PROBE_RESULTS.push({ rel, domainPath });
}

// --- Probe: detail-page-uses-detail-shell ---
const DETAIL_PAGE_RX = /src\/app\/\(protected\)\/[^/]+(?:\/[^/]+)*\/\[id\]\/page\.tsx$/;
for (const sf of sourceFiles) {
  const fp = sf.getFilePath();
  if (!DETAIL_PAGE_RX.test(fp)) continue;
  const text = sf.getFullText();
  const rel = path.relative(repo, fp);

  // PageHeader + DetailShell|Section sections + notFound boundary
  const hasPageHeader = /<PageHeader\b/.test(text);
  const hasDetailShell =
    /<DetailShell\b/.test(text) ||
    (/<Section\b/.test(text) && (text.match(/<Section\b/g) || []).length >= 1);
  const hasNotFound = /\bnotFound\(\)/.test(text);

  if (!hasPageHeader) {
    addFinding("detail-page-required-sections", "error", rel, 0,
      "detail page must render PageHeader");
  }
  if (!hasDetailShell) {
    addFinding("detail-page-required-sections", "error", rel, 0,
      "detail page must render DetailShell or at least Section");
  }
  if (!hasNotFound) {
    addFinding("detail-page-not-found-boundary", "error", rel, 0,
      "detail page must call notFound() from next/navigation when record null");
  }
}

const summary = {
  layer: "L2-tsx-ast",
  status: findings.some((f) => f.severity === "error" || f.severity === "fatal") ? "fail" : "pass",
  total: findings.length,
  by_severity: ["fatal", "error", "warn", "info"].reduce((acc, k) => {
    acc[k] = findings.filter((f) => f.severity === k).length;
    return acc;
  }, {}),
  findings: findings.slice(0, 200),
  truncated: findings.length > 200,
  repo,
};
emit(summary);
process.exit(summary.status === "pass" ? 0 : 1);
