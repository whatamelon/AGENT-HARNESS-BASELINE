#!/usr/bin/env python3
"""
admin-design-gate — Codex CLI hook dispatcher for admin-design SSOT.

Mirrors ~/.config/agent-harness-baseline/claude/hooks/admin_design_gate.py
for Codex's hook lifecycle.

Events (Codex emits via hook_event_name in stdin JSON):
- SessionStart, UserPromptSubmit, PreToolUse, PermissionRequest,
  PostToolUse, PreCompact, PostCompact, SubagentStart, SubagentStop, Stop

permission_mode payload field is leveraged (default|acceptEdits|plan|dontAsk|bypassPermissions).
Note: Codex PreToolUse cannot fully intercept all tool paths — combine with
post-verify (PostToolUse) + admin-build verify (external).
"""
from __future__ import annotations

import json
import os
import re
import sys
import time
from pathlib import Path

HOME = Path.home()
SSOT_ROOT = Path(os.environ.get("ADMIN_DESIGN_ROOT",
                                HOME / ".config/agent-harness-baseline/admin-design"))
SEC_ROOT = Path(os.environ.get("ADMIN_SECURITY_ROOT",
                               HOME / ".config/agent-harness-baseline/admin-security"))
LOG_PATH = HOME / ".codex/logs/admin-design-gate.jsonl"
LOG_PATH.parent.mkdir(parents=True, exist_ok=True)

ADMIN_KEYWORDS = re.compile(
    r"(어드민|관리자|대시보드|운영툴|백오피스|admin(?!\w)|back[- ]?office|"
    r"dashboard|admin-build|/admin-build|어드민\s*1샷|one[- ]?shot\s*admin|"
    r"ERP|CRM|관리\s*페이지|admin\s*panel)",
    re.IGNORECASE,
)

ADMIN_ROUTE_RE = re.compile(
    r"(^|/)("
    r"app/\(admin\)/|"
    r"app/admin/|"
    r"app/\(protected\)/admin/|"
    r"src/app/\(admin\)/|"
    r"src/app/admin/|"
    r"src/app/\(protected\)/admin/|"
    r"src/routes/admin/|"
    r"src/features/admin/|"
    r"src/components/admin/|"
    r"admin/admin-design/local\.md"
    r")"
)


def log(event: str, payload: dict) -> None:
    rec = {"ts": time.time(), "event": event, "cli": "codex", **payload}
    try:
        with LOG_PATH.open("a") as f:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
    except Exception:
        pass


def load_manifest() -> dict:
    p = SSOT_ROOT / "manifest.json"
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text())
    except Exception:
        return {}


def manifest_summary() -> str:
    m = load_manifest()
    if not m:
        return "[admin-design-gate] manifest.json missing; SSOT not initialized."
    files = m.get("files", {})
    routes = m.get("task_router", {})
    return "\n".join([
        f"[admin-design SSOT v{m.get('version', '?')} | {len(files)} sections]",
        f"  always_load: 00-non-negotiable.md, 02-ssot-protocol.md, index.md",
        f"  task_router: {', '.join(sorted(routes.keys()))}",
        f"  attestation required: {m.get('attestation_required', True)}",
        "  Tier 0 = forbidden override. Tier 1 global / Tier 2 local.md (additive) / Tier 3 task prompt.",
        "  Before first admin route edit: emit .admin-build/runs/<ts>/ssot_attestation.json.",
    ])


def detect_task_type(prompt: str) -> list[str]:
    p = prompt.lower()
    tasks = []
    if any(k in p for k in ("어드민 만들", "scaffold", "bootstrap", "신규 어드민")):
        tasks.append("admin-bootstrap")
    if any(k in p for k in ("리스트", "목록", "list page", "table", "테이블")):
        tasks.append("list-page")
    if any(k in p for k in ("상세", "detail page", "detail")):
        tasks.append("detail-page")
    if any(k in p for k in ("폼", "form", "create", "edit")):
        tasks.append("form-page")
    if any(k in p for k in ("모달", "modal", "drawer", "sheet", "popover")):
        tasks.append("modal-or-drawer")
    if any(k in p for k in ("대시보드", "dashboard", "kpi", "chart")):
        tasks.append("dashboard-page")
    if any(k in p for k in ("rbac", "권한", "permission", "rls", "auth")):
        tasks.append("rbac-implementation")
    for dom in ("erp", "commerce", "finance", "crm", "marketing"):
        if dom in p:
            tasks.append(f"domain-{dom}")
    if any(k in p for k in ("검수", "acceptance", "완료")):
        tasks.append("acceptance-check")
    return tasks or ["admin-bootstrap"]


def sections_for_tasks(tasks: list[str]) -> list[str]:
    m = load_manifest()
    routes = m.get("task_router", {})
    out, seen = [], set()
    for t in tasks:
        for s in routes.get(t, []):
            if s not in seen:
                out.append(s)
                seen.add(s)
    return out


def find_attestation() -> Path | None:
    cwd = Path(os.getcwd())
    for d in [cwd, *cwd.parents]:
        runs = d / ".admin-build" / "runs"
        if runs.is_dir():
            latest = None
            for entry in runs.iterdir():
                if not entry.is_dir():
                    continue
                att = entry / "ssot_attestation.json"
                if att.exists():
                    if latest is None or entry.stat().st_mtime > latest[1]:
                        latest = (att, entry.stat().st_mtime)
            if latest:
                return latest[0]
    return None


def is_admin_path(path: str) -> bool:
    return bool(ADMIN_ROUTE_RE.search(path or ""))


QUICK_GREP = [
    (re.compile(r"\bdark:|\.dark\b|className=\"dark"), "L1 violation: dark mode class (Tier 0)"),
    (re.compile(r"SUPABASE_SERVICE_ROLE_KEY|service_role"), "L1 violation: service_role leak"),
    (re.compile(r"shadow-2xl|drop-shadow-\[0_.+_40px\]"), "L1 violation: heavy card shadow"),
    (re.compile(r"focus:outline-none(?!\s+focus-visible:|\s+focus:ring)"), "L1 violation: outline removed without replacement"),
]


# ---------- Event handlers (Codex) ----------

def on_session_start(payload: dict) -> dict:
    return {"additionalContext": manifest_summary()}


def on_user_prompt_submit(payload: dict) -> dict:
    prompt = payload.get("prompt") or payload.get("user_prompt") or ""
    if not ADMIN_KEYWORDS.search(prompt):
        return {}
    tasks = detect_task_type(prompt)
    sections = sections_for_tasks(tasks)
    sec_lines = [f"  - {SSOT_ROOT}/{s}.md" for s in sections]
    text = "\n".join([
        "[admin-design-gate] admin keyword detected.",
        f"  detected task types: {', '.join(tasks)}",
        "  load these SSOT sections (lazy):",
        *sec_lines,
        "",
        "  also always-load: 00-non-negotiable.md, 02-ssot-protocol.md, index.md",
        "  before first admin route apply_patch: emit .admin-build/runs/<ts>/ssot_attestation.json",
        "  RBAC fixtures: ~/.codex/admin-security/_rbac-matrix.yaml",
    ])
    log("UserPromptSubmit:admin", {"tasks": tasks, "sections": sections})
    return {"additionalContext": text}


def on_pre_tool_use(payload: dict) -> dict:
    """Codex PreToolUse cannot fully intercept all paths — best-effort guard."""
    tool = payload.get("tool_name") or payload.get("tool") or ""
    inp = payload.get("tool_input") or payload.get("input") or {}
    target = inp.get("file_path") or inp.get("path") or inp.get("command") or ""
    if not is_admin_path(target):
        return {}
    perm_mode = payload.get("permission_mode", "default")
    if perm_mode == "bypassPermissions":
        log("PreToolUse:bypass", {"tool": tool, "target": target})
        return {}
    att = find_attestation()
    if att is None:
        msg = ("[admin-design-gate] admin route edit attempted without "
               ".admin-build/runs/<ts>/ssot_attestation.json. "
               "Run `admin-build attest --task <kind>` first.")
        log("PreToolUse:deny:no-attestation", {"tool": tool, "target": target})
        return {"permissionDecision": "deny", "permissionDecisionReason": msg}
    return {"additionalContext": f"attestation present: {att}"}


def on_permission_request(payload: dict) -> dict:
    return on_pre_tool_use(payload)


def on_post_tool_use(payload: dict) -> dict:
    tool = payload.get("tool_name") or payload.get("tool") or ""
    inp = payload.get("tool_input") or payload.get("input") or {}
    target = inp.get("file_path") or inp.get("path") or ""
    if not is_admin_path(target):
        return {}
    p = Path(target)
    if not p.exists() or p.is_dir():
        return {}
    try:
        text = p.read_text(errors="ignore")
    except Exception:
        return {}
    hits = []
    for rx, reason in QUICK_GREP:
        m = rx.search(text)
        if m:
            hits.append(f"  - {reason}: matched `{m.group(0)[:40]}`")
    if not hits:
        return {}
    log("PostToolUse:quick-grep:hits", {"target": target, "count": len(hits)})
    return {
        "additionalContext": ("[admin-design-gate] quick-grep warning:\n"
                              + "\n".join(hits)
                              + "\n  full verifier: `admin-build verify` (4-layer)"),
    }


def on_subagent_start(payload: dict) -> dict:
    return on_session_start(payload)


def on_subagent_stop(payload: dict) -> dict:
    return on_stop(payload)


def on_stop(payload: dict) -> dict:
    cwd = Path(os.getcwd())
    for d in [cwd, *cwd.parents]:
        marker = d / ".admin-build" / "VERIFIER_FAIL"
        if marker.exists():
            try:
                detail = marker.read_text()
            except Exception:
                detail = "verifier failed; details unavailable"
            log("Stop:block", {"marker": str(marker)})
            return {
                "decision": "block",
                "reason": ("[admin-design-gate] 4-layer verifier failed. "
                           "Re-run `admin-build verify`.\n" + detail[:500]),
            }
    return {}


def on_pre_compact(payload: dict) -> dict:
    return {"additionalContext": manifest_summary()}


def on_post_compact(payload: dict) -> dict:
    return on_pre_compact(payload)


DISPATCH = {
    "SessionStart": on_session_start,
    "UserPromptSubmit": on_user_prompt_submit,
    "PreToolUse": on_pre_tool_use,
    "PermissionRequest": on_permission_request,
    "PostToolUse": on_post_tool_use,
    "PreCompact": on_pre_compact,
    "PostCompact": on_post_compact,
    "SubagentStart": on_subagent_start,
    "SubagentStop": on_subagent_stop,
    "Stop": on_stop,
}


def main() -> int:
    raw = sys.stdin.read() or "{}"
    try:
        payload = json.loads(raw)
    except Exception:
        payload = {}
    event = (payload.get("hook_event_name")
             or (sys.argv[1] if len(sys.argv) > 1 else "")
             or "")
    handler = DISPATCH.get(event)
    if handler is None:
        return 0
    try:
        out = handler(payload) or {}
    except Exception as e:
        log(f"{event}:exception", {"err": str(e)})
        return 0
    if out:
        sys.stdout.write(json.dumps(out, ensure_ascii=False))
        sys.stdout.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())
