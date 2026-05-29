#!/usr/bin/env python3
"""
L1 static grep verifier.

Reads:
  ~/.config/agent-harness-baseline/admin-design/machine/checklist.yaml
  ~/.config/agent-harness-baseline/admin-security/_secret-leak.yaml

Scans <repo> (argv[1]) for:
  - L1 probes from checklist.yaml (grep + allow/forbid path glob)
  - secret-leak.yaml patterns (fatal)

Exit:
  0 — pass (no fatal/error)
  1 — fail (any fatal or error)
"""
from __future__ import annotations

import fnmatch
import json
import os
import re
import sys
from pathlib import Path

try:
    import yaml as _yaml
    HAS_YAML = True
except Exception:
    _yaml = None
    HAS_YAML = False

HOME = Path.home()
SSOT_ROOT = Path(os.environ.get("ADMIN_DESIGN_ROOT",
                                HOME / ".config/agent-harness-baseline/admin-design"))
SEC_ROOT = Path(os.environ.get("ADMIN_SECURITY_ROOT",
                               HOME / ".config/agent-harness-baseline/admin-security"))

CODE_EXT = {".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".css", ".scss", ".html", ".svelte", ".vue"}
IGNORE_DIRS = {".git", "node_modules", ".next", "dist", "build", "coverage",
               ".turbo", ".vercel", "out", ".cache", ".pnpm-store", ".admin-build"}


def iter_files(root: Path):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in IGNORE_DIRS and not d.startswith(".venv")]
        for fn in filenames:
            p = Path(dirpath) / fn
            if p.suffix in CODE_EXT:
                yield p


def match_any(rel: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatch(rel, pat) for pat in patterns)


# Hardcoded fallback probes (when pyyaml missing). Mirrors checklist.yaml L1 subset.
FALLBACK_L1 = [
    {"id": "no-dark-class", "severity": "fatal",
     "grep": r"dark:|\.dark\b|className=\"dark|prefers-color-scheme:\s*dark",
     "expect": 0},
    {"id": "dark-token-block-absent", "severity": "fatal",
     "grep": r"^\s*\.dark\s*\{|\.dark:root\s*\{|@media\s*\(prefers-color-scheme:\s*dark\)",
     "expect": 0},
    {"id": "no-heavy-card-shadow", "severity": "warn",
     "grep": r"shadow-2xl|drop-shadow-\[0_.+_40px\]|shadow-\[0_.+_60px\]",
     "expect": 0},
    {"id": "focus-ring-present", "severity": "error",
     "grep": r"focus:outline-none(?!\s+focus-visible:|\s+focus:ring)",
     "expect": 0,
     "reason": "outline removed without focus-visible:ring replacement"},
    {"id": "no-stack-trace-in-ui", "severity": "error",
     "grep": r"error\.stack|err\.stack",
     "expect": 0,
     "allow_paths": ["src/lib/errors/*", "debug/*", "dev/*"],
     "forbid_paths": ["src/components/admin/*", "src/features/*/components/*", "app/*/page.tsx"]},
]


def run_checklist_probes(repo: Path) -> list[dict]:
    cl_path = SSOT_ROOT / "machine" / "checklist.yaml"
    if HAS_YAML and cl_path.exists():
        spec = _yaml.safe_load(cl_path.read_text())
    elif cl_path.exists() and not HAS_YAML:
        spec = {"probes": FALLBACK_L1}
        sys.stderr.write("[static-grep] pyyaml missing — using hardcoded fallback (subset).\n")
    elif not cl_path.exists():
        return [{"id": "checklist-missing", "severity": "fatal", "msg": str(cl_path)}]
    hits = []
    for probe in spec.get("probes", []):
        if probe.get("layer") not in {"L1"}:
            continue
        pattern = probe.get("grep")
        if not pattern:
            continue
        try:
            rx = re.compile(pattern)
        except re.error as e:
            hits.append({"id": probe["id"], "severity": "error",
                         "msg": f"invalid regex: {e}"})
            continue
        forbid = probe.get("forbid_paths") or []
        allow = probe.get("allow_paths") or []
        expect = probe.get("expect")
        for p in iter_files(repo):
            rel = str(p.relative_to(repo))
            if allow and match_any(rel, allow):
                continue
            if forbid and not match_any(rel, forbid):
                continue
            try:
                text = p.read_text(errors="ignore")
            except Exception:
                continue
            for m in rx.finditer(text):
                # 라인 정보
                line = text.count("\n", 0, m.start()) + 1
                if expect == 0:
                    hits.append({"id": probe["id"], "severity": probe.get("severity", "error"),
                                 "path": rel, "line": line, "match": m.group(0)[:80],
                                 "reason": probe.get("reason", "")})
                else:
                    # default: probe wants to count occurrences; treat any match as a hit
                    hits.append({"id": probe["id"], "severity": probe.get("severity", "warn"),
                                 "path": rel, "line": line, "match": m.group(0)[:80],
                                 "reason": probe.get("reason", "")})
    return hits


# Hardcoded secret-leak fallback (when pyyaml missing).
FALLBACK_SECRETS = [
    {"id": "supabase-service-role", "pattern": r"SUPABASE_SERVICE_ROLE_KEY|service_role", "severity": "fatal"},
    {"id": "stripe-secret", "pattern": r"STRIPE_SECRET_KEY|sk_live_|sk_test_[a-zA-Z0-9]{20,}", "severity": "fatal"},
    {"id": "openai-key", "pattern": r"OPENAI_API_KEY|sk-[a-zA-Z0-9]{20,}", "severity": "fatal"},
    {"id": "anthropic-key", "pattern": r"ANTHROPIC_API_KEY|sk-ant-[a-zA-Z0-9_-]{20,}", "severity": "fatal"},
    {"id": "jwt-secret", "pattern": r"JWT_SECRET|JWT_SIGNING_KEY", "severity": "fatal"},
    {"id": "github-pat", "pattern": r"ghp_[a-zA-Z0-9]{36}", "severity": "fatal"},
    {"id": "aws-access-key", "pattern": r"AKIA[0-9A-Z]{16}", "severity": "fatal"},
]
FALLBACK_SECRET_FORBID = [
    "src/components/*", "src/features/*/components/*",
    "app/*/page.tsx", "app/*/layout.tsx", "public/*",
]
FALLBACK_SECRET_ALLOW = [
    "src/server/*", "src/lib/server/*", "app/api/*",
    "supabase/functions/*", ".env*", "scripts/*",
    "*.test.ts", "*.spec.ts",
]


def run_secret_leak(repo: Path) -> list[dict]:
    sl_path = SEC_ROOT / "_secret-leak.yaml"
    if HAS_YAML and sl_path.exists():
        spec = _yaml.safe_load(sl_path.read_text())
    elif sl_path.exists() and not HAS_YAML:
        spec = {"patterns": FALLBACK_SECRETS,
                "forbid_paths": FALLBACK_SECRET_FORBID,
                "allow_paths": FALLBACK_SECRET_ALLOW}
    elif not sl_path.exists():
        return []
    else:
        return []
    hits = []
    forbid = spec.get("forbid_paths", []) or []
    allow = spec.get("allow_paths", []) or []
    patterns = []
    for p in spec.get("patterns", []) or []:
        try:
            rx = re.compile(p["pattern"])
            patterns.append((p["id"], rx, p.get("severity", "fatal")))
        except re.error as e:
            hits.append({"id": p.get("id"), "severity": "error", "msg": f"invalid regex: {e}"})
    for p in iter_files(repo):
        rel = str(p.relative_to(repo))
        if allow and match_any(rel, allow):
            continue
        if forbid and not match_any(rel, forbid):
            continue
        try:
            text = p.read_text(errors="ignore")
        except Exception:
            continue
        for pid, rx, sev in patterns:
            for m in rx.finditer(text):
                line = text.count("\n", 0, m.start()) + 1
                hits.append({"id": pid, "severity": sev, "path": rel,
                             "line": line, "match": m.group(0)[:60]})
    return hits


def check_list_detail_pairing(repo: Path) -> list[dict]:
    """
    Detail page pairing: 모든 list page 마다 [id] detail page file 존재 확인.

    Source A — routes.json (orchestrator emit). type=list_page 인 row 마다 같은 path + '/[id]'
    인 detail row 또는 file system 의 sibling [id]/page.tsx 검사.
    Source B (fallback) — `src/app/(protected)/**/page.tsx` 글로벌 file system 스캔.
    """
    hits = []

    # Source A — routes.json
    routes_path = repo / ".admin-build" / "routes.json"
    list_paths_from_routes = set()
    detail_paths_from_routes = set()
    if routes_path.exists():
        try:
            routes = json.loads(routes_path.read_text())
            for r in routes:
                p = (r.get("path") or "").rstrip("/")
                t = r.get("type") or ""
                if t == "list_page":
                    list_paths_from_routes.add(p)
                elif t == "detail_page":
                    detail_paths_from_routes.add(p)
            for lp in sorted(list_paths_from_routes):
                expected = {lp + "/[id]", lp + "/:id", lp + "/[slug]"}
                if not any(d in expected for d in detail_paths_from_routes):
                    hits.append({
                        "id": "detail-page-paired-with-list",
                        "severity": "fatal",
                        "path": lp,
                        "reason": "list page missing paired detail [id] route in routes.json",
                    })
        except Exception as e:
            hits.append({"id": "detail-page-paired-with-list",
                         "severity": "warn", "msg": f"routes.json parse error: {e}"})

    # Source B — file system (always run as cross-check)
    list_pattern = re.compile(r"src/app/\(protected\)/([^/]+)/page\.tsx$")
    found_list_dirs: set[str] = set()
    SKIP_LIST_DOMAINS = {"dashboard", "settings", "carmanager", "leads"}  # hub/dashboard/form — list-page 아님
    for p in iter_files(repo):
        rel = str(p.relative_to(repo))
        m = list_pattern.search(rel)
        if not m:
            continue
        domain = m.group(1)
        if domain in SKIP_LIST_DOMAINS:
            continue
        # nested page (e.g., /leads/consultations) 처리 위해 더 깊은 path 도 받음
        list_dir = p.parent
        # detail = sibling [id]/page.tsx
        detail = list_dir / "[id]" / "page.tsx"
        if not detail.exists():
            hits.append({
                "id": "detail-page-paired-with-list",
                "severity": "fatal",
                "path": str(list_dir.relative_to(repo)),
                "reason": f"missing detail page: {detail.relative_to(repo)}",
            })
            found_list_dirs.add(str(list_dir.relative_to(repo)))
    return hits


def check_list_page_required_components(repo: Path) -> list[dict]:
    """
    L1 fallback (ts-morph 없을 때) — list page source 안에 4 의무 컴포넌트 grep.

      1. DataTable
      2. DataToolbar | FilterBar | search Input
      3. PaginationLinks | PaginationBar
      4. FilterChip | <select>

    SKIP 결정 우선순위:
      A. routes.json 존재 시 — type=="list_page" path 만 검사. 나머지 type
         (sub_list_terminal / form_page / hub_page / dashboard_page / detail_page) skip.
      B. routes.json 없으면 fallback — SKIP_DOMAINS set 만 사용.
    """
    # Source A — routes.json
    routes_path = repo / ".admin-build" / "routes.json"
    list_page_route_set = None
    if routes_path.exists():
        try:
            routes = json.loads(routes_path.read_text())
            list_page_route_set = {
                (r.get("path") or "").rstrip("/")
                for r in routes
                if r.get("type") == "list_page"
            }
            list_page_route_set.discard("")
        except Exception:
            list_page_route_set = None

    SKIP = {"dashboard", "settings", "carmanager", "leads"}
    hits = []
    list_re = re.compile(
        r"src/app/\(protected\)/((?:[a-z-]+(?:/[a-z-]+)*?))/page\.tsx$"
    )
    for p in iter_files(repo):
        rel = str(p.relative_to(repo))
        m = list_re.search(rel)
        if not m:
            continue
        if "/[id]/" in rel:
            continue
        domain_path = m.group(1)

        if list_page_route_set is not None:
            # Source A — routes.json 모드
            route_path = "/" + domain_path
            if route_path not in list_page_route_set:
                continue
        else:
            # Source B — fallback
            first = domain_path.split("/")[0]
            if first in SKIP and "/" not in domain_path:
                continue
        try:
            text = p.read_text(errors="ignore")
        except Exception:
            continue

        has_data_table = "<DataTable" in text or "@tanstack/react-table" in text
        if not has_data_table:
            hits.append({"id": "list-page-uses-data-table", "severity": "error",
                         "path": rel, "reason": "no <DataTable> or TanStack import"})

        has_toolbar = (
            "<DataToolbar" in text
            or "<FilterBar" in text
            or ("<Input" in text and ("검색" in text or "search" in text.lower()))
        )
        if not has_toolbar:
            hits.append({"id": "list-page-has-filter-bar", "severity": "error",
                         "path": rel,
                         "reason": "no DataToolbar/FilterBar/search Input"})

        has_pagination = "<PaginationLinks" in text or "<PaginationBar" in text
        if not has_pagination:
            hits.append({"id": "list-page-has-pagination-bar", "severity": "error",
                         "path": rel,
                         "reason": "no PaginationLinks/PaginationBar"})

        has_filter_chip = (
            "<FilterChip" in text
            or "<FilterChipGroup" in text
            or "<select" in text
        )
        if not has_filter_chip:
            hits.append({"id": "list-page-has-filter-chip", "severity": "warn",
                         "path": rel,
                         "reason": "no FilterChip/FilterChipGroup/<select> filter"})
    return hits


def check_shared_table_components(repo: Path) -> list[dict]:
    """
    공유 테이블 컴포넌트 3종 강제 (2026-05-29, §12.9~12.11):
      1. sticky-table-header   — DataTable thead 가 sticky top-0 + opaque bg
      2. status-filter-colored — FilterChip 이 tone/toneFor 기반 색칠 지원
      3. pk-cell-helper-present — pk-cell.tsx 가 pkColumn + PkLink export

    이들은 라우트별이 아니라 단일 공유 컴포넌트라 파일 존재/내용 grep 으로 충분.
    """
    hits = []

    # 1. DataTable thead sticky + opaque bg
    dt = repo / "src" / "components" / "admin" / "data-table" / "data-table.tsx"
    if dt.exists():
        txt = dt.read_text(errors="ignore")
        thead_idx = txt.find("<thead")
        thead_line = txt[thead_idx:txt.find(">", thead_idx)] if thead_idx >= 0 else ""
        if "sticky top-0" not in thead_line:
            hits.append({"id": "sticky-table-header", "severity": "error",
                         "path": str(dt.relative_to(repo)),
                         "reason": "DataTable <thead> 에 'sticky top-0' 부재 — 리스트 헤더가 스크롤에 사라짐 (§12.10)"})
        # opaque bg: bg-muted/bg-card/bg-background 가 /NN opacity suffix 없이
        elif not re.search(r"bg-(muted|card|background)(?!/)\b", thead_line):
            hits.append({"id": "sticky-table-header", "severity": "error",
                         "path": str(dt.relative_to(repo)),
                         "reason": "sticky thead 에 opaque bg(bg-muted/bg-card/bg-background) 부재 — 반투명이면 row 가 비침 (§12.10)"})
        # wrapper overflow-hidden 이 sticky 무력화
        if re.search(r"overflow-hidden[^\"']*\"[\s\S]{0,40}<table", txt):
            hits.append({"id": "sticky-table-header", "severity": "error",
                         "path": str(dt.relative_to(repo)),
                         "reason": "table wrapper 에 overflow-hidden — page sticky 무력화 (§12.10)"})

    # 2. FilterChip semantic color
    tb = repo / "src" / "components" / "admin" / "data-table" / "data-toolbar.tsx"
    if tb.exists():
        txt = tb.read_text(errors="ignore")
        if "toneFor(" not in txt or "StatusTone" not in txt:
            hits.append({"id": "status-filter-colored", "severity": "error",
                         "path": str(tb.relative_to(repo)),
                         "reason": "FilterChip 이 toneFor/StatusTone 기반 색칠 미지원 — status 필터가 무채 (§12.11)"})

    # 3. pk-cell helper
    pk = repo / "src" / "components" / "admin" / "data-table" / "pk-cell.tsx"
    if not pk.exists():
        hits.append({"id": "pk-cell-helper-present", "severity": "error",
                     "path": "src/components/admin/data-table/pk-cell.tsx",
                     "reason": "PK 단일 진입 공유 출구(pk-cell.tsx) 부재 (§12.9)"})
    else:
        txt = pk.read_text(errors="ignore")
        if "pkColumn" not in txt or "PkLink" not in txt:
            hits.append({"id": "pk-cell-helper-present", "severity": "error",
                         "path": str(pk.relative_to(repo)),
                         "reason": "pk-cell.tsx 가 pkColumn + PkLink 를 export 하지 않음 (§12.9)"})

    # 4. pagination preserves search params (2026-05-29 audit §12.12)
    pl = repo / "src" / "components" / "admin" / "data-table" / "pagination-links.tsx"
    if pl.exists():
        txt = pl.read_text(errors="ignore")
        clones = "useSearchParams" in txt and "URLSearchParams" in txt
        # bare object href that replaces whole query: href={{ query: { ... } }}
        bare = re.search(r"href=\{\{\s*query\s*:", txt)
        if not clones or bare:
            hits.append({"id": "pagination-preserves-params", "severity": "error",
                         "path": str(pl.relative_to(repo)),
                         "reason": "page link 가 현재 search param 을 clone(useSearchParams+URLSearchParams)하지 않거나 bare {query:{...}} href 사용 — 페이지 이동 시 필터/정렬 소실 (§12.12)"})

    # 5. column sort opt-in server-side (§12.13)
    if dt.exists():
        dtx = dt.read_text(errors="ignore")
        if "sortKey" not in dtx or "useSearchParams" not in dtx:
            hits.append({"id": "column-sort-opt-in", "severity": "error",
                         "path": str(dt.relative_to(repo)),
                         "reason": "DataTable 에 sortKey opt-in + useSearchParams 기반 URL 정렬 부재 — 정렬 MUST 가 dead (§12.13)"})
        if re.search(r"getSortedRowModel\s*\(", dtx):
            hits.append({"id": "column-sort-opt-in", "severity": "warn",
                         "path": str(dt.relative_to(repo)),
                         "reason": "getSortedRowModel(클라이언트 정렬) 호출 — server-side 정렬(URL sort/order) 정책과 불일치 (§12.13)"})

    # 6. DateCell tooltip helper (§12.14)
    dc = repo / "src" / "components" / "admin" / "data-table" / "date-cell.tsx"
    if not dc.exists():
        hits.append({"id": "date-cell-tooltip", "severity": "error",
                     "path": "src/components/admin/data-table/date-cell.tsx",
                     "reason": "DateCell(title=정확 timestamp) 공유 컴포넌트 부재 — date 셀 tooltip 누락 (§12.14)"})
    else:
        dcx = dc.read_text(errors="ignore")
        if "DateCell" not in dcx or "title" not in dcx:
            hits.append({"id": "date-cell-tooltip", "severity": "error",
                         "path": str(dc.relative_to(repo)),
                         "reason": "date-cell.tsx 가 DateCell + title(exact timestamp) 미제공 (§12.14)"})

    # 7. clear-all filters affordance (§12.15)
    if tb.exists():
        tbx = tb.read_text(errors="ignore")
        if "필터 초기화" not in tbx and "clearAll" not in tbx and "clear-all" not in tbx:
            hits.append({"id": "clear-all-filters", "severity": "warn",
                         "path": str(tb.relative_to(repo)),
                         "reason": "DataToolbar 에 clear-all(필터 초기화) affordance 부재 (§12.15)"})

    # 8. fake hover:underline on non-link table cells (§12.15)
    comp_glob = repo / "src" / "app" / "(protected)"
    if comp_glob.exists():
        for p in comp_glob.rglob("_components/*-table.tsx"):
            t = p.read_text(errors="ignore")
            if "hover:underline" in t:
                hits.append({"id": "no-fake-hover-underline", "severity": "error",
                             "path": str(p.relative_to(repo)),
                             "reason": "비-link 셀 hover:underline = fake affordance. 행 underline 은 PkLink 만 (§12.15)"})

    return hits


def main() -> int:
    if len(sys.argv) < 2:
        sys.stderr.write("usage: static-grep.py <repo-root>\n")
        return 2
    repo = Path(sys.argv[1]).resolve()
    if not repo.is_dir():
        sys.stderr.write(f"not a directory: {repo}\n")
        return 2

    cl_hits = run_checklist_probes(repo)
    sl_hits = run_secret_leak(repo)
    pair_hits = check_list_detail_pairing(repo)
    list_comp_hits = check_list_page_required_components(repo)
    shared_comp_hits = check_shared_table_components(repo)
    all_hits = cl_hits + sl_hits + pair_hits + list_comp_hits + shared_comp_hits

    fatal = [h for h in all_hits if h.get("severity") == "fatal"]
    error = [h for h in all_hits if h.get("severity") == "error"]
    warn = [h for h in all_hits if h.get("severity") == "warn"]
    info = [h for h in all_hits if h.get("severity") == "info"]

    report = {
        "layer": "L1-static-grep",
        "repo": str(repo),
        "total": len(all_hits),
        "by_severity": {"fatal": len(fatal), "error": len(error), "warn": len(warn), "info": len(info)},
        "hits": all_hits[:200],
        "truncated": len(all_hits) > 200,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))

    return 0 if (not fatal and not error) else 1


if __name__ == "__main__":
    sys.exit(main())
