#!/usr/bin/env python3
"""
admin-design-gate — Claude Code hook dispatcher for admin-design SSOT.

Events handled (dispatched via $1 or hook_event_name from stdin JSON):
- SessionStart        : inject manifest summary as additionalContext
- UserPromptSubmit    : detect admin keyword, inject task→section mapping
- UserPromptExpansion : detect /admin-build slash command, inject attestation guidance
- PreToolUse          : when Write/Edit/Bash touches admin route, require ssot_attestation.json
- PostToolUse         : changed file L1 quick scan (grep dark mode / service_role / etc)
- Stop                : if verifier-fail marker present, continue conversation (8회 cap 회피용 외부 orchestrator 가 최종 책임)

Soft enforcement by default. permissionDecision=deny on critical violations:
- Edit/Write on admin route with no attestation
- Stop with verifier-fail marker

Reads SSOT from:
  $ADMIN_DESIGN_ROOT (default: ~/.config/agent-harness-baseline/admin-design)
  $ADMIN_SECURITY_ROOT (default: ~/.config/agent-harness-baseline/admin-security)

Writes audit log to: ~/.claude/logs/admin-design-gate.jsonl
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
LOG_PATH = HOME / ".claude/logs/admin-design-gate.jsonl"
LOG_PATH.parent.mkdir(parents=True, exist_ok=True)

# --- Trigger keyword (admin/back-office/dashboard work) ---
ADMIN_KEYWORDS = re.compile(
    r"(어드민|관리자|대시보드|운영툴|백오피스|admin(?!\w)|back[- ]?office|"
    r"dashboard|admin-build|/admin-build|어드민\s*1샷|one[- ]?shot\s*admin|"
    r"ERP|CRM|관리\s*페이지|admin\s*panel)",
    re.IGNORECASE,
)

# --- Admin route file patterns ---
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
    rec = {"ts": time.time(), "event": event, **payload}
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
    lines = [
        f"[admin-design SSOT v{m.get('version', '?')} loaded — {len(files)} sections]",
        f"  always_load: 00-non-negotiable.md, 02-ssot-protocol.md, index.md",
        f"  task_router keys: {', '.join(sorted(routes.keys()))}",
        f"  attestation required: {m.get('attestation_required', True)}",
        f"  verifier entrypoint: {m.get('verifier_entrypoint', '<missing>')}",
        "",
        "Rules:",
        "  Tier 0 = override forbidden. Tier 1 = global. Tier 2 = repo local.md (additive). Tier 3 = task prompt.",
        "  Before first admin route edit: create .admin-build/runs/<ts>/ssot_attestation.json.",
        "  Before stopping: run `admin-build verify` (4-layer).",
    ]
    return "\n".join(lines)


def detect_task_type(prompt: str) -> list[str]:
    """Map prompt keywords to manifest.task_router keys."""
    p = prompt.lower()
    tasks = []
    if any(k in p for k in ("어드민 만들", "scaffold", "bootstrap", "처음부터", "신규 어드민")):
        tasks.append("admin-bootstrap")
    if any(k in p for k in ("리스트", "목록", "list page", "table", "테이블")):
        tasks.append("list-page")
    if any(k in p for k in ("상세", "detail page", "detail")):
        tasks.append("detail-page")
    if any(k in p for k in ("폼", "form", "create", "edit", "create-edit")):
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
    if any(k in p for k in ("검수", "acceptance", "최종", "완료")):
        tasks.append("acceptance-check")
    return tasks or ["admin-bootstrap"]


def sections_for_tasks(tasks: list[str]) -> list[str]:
    m = load_manifest()
    routes = m.get("task_router", {})
    out: list[str] = []
    seen = set()
    for t in tasks:
        for s in routes.get(t, []):
            if s not in seen:
                out.append(s)
                seen.add(s)
    return out


def find_attestation() -> Path | None:
    """Find latest .admin-build/runs/<ts>/ssot_attestation.json in cwd or upwards."""
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


# ---------- Event handlers ----------

def on_session_start(payload: dict) -> dict:
    """Inject manifest summary as additionalContext (always — light cost)."""
    summary = manifest_summary()
    return {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": summary,
        }
    }


def on_user_prompt_submit(payload: dict) -> dict:
    prompt = payload.get("prompt", "") or ""
    if not ADMIN_KEYWORDS.search(prompt):
        return {}  # not admin work; silent

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
        "  before first admin route edit: create .admin-build/runs/<ts>/ssot_attestation.json",
        "  see ~/.codex/admin-security/_rbac-matrix.yaml for RBAC fixtures.",
    ])
    log("UserPromptSubmit:admin", {"tasks": tasks, "sections": sections})
    return {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": text,
        }
    }


def on_user_prompt_expansion(payload: dict) -> dict:
    cmd = (payload.get("command_name") or "").lower()
    if cmd not in {"admin-build", "admin-design", "admin-design-verify"}:
        return {}
    msg = "\n".join([
        f"[admin-design-gate] slash command /{cmd} expanded.",
        "  required steps:",
        "  1. Load manifest.json + index.md + 00-non-negotiable.md + 02-ssot-protocol.md",
        "  2. Resolve task → section mapping via manifest.task_router",
        "  3. Read mapped sections (lazy)",
        "  4. Create .admin-build/runs/<ts>/ssot_attestation.json",
        "  5. Implement (lane-isolated if multi-worker)",
        "  6. Run `admin-build verify` (4-layer L1+L2+L3+L4)",
        "  7. Emit run audit at .admin-build/runs/<ts>/final-verdict.md",
    ])
    log("UserPromptExpansion", {"command": cmd})
    return {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptExpansion",
            "additionalContext": msg,
        }
    }


def on_pre_tool_use(payload: dict) -> dict:
    tool = payload.get("tool_name") or payload.get("tool") or ""
    inp = payload.get("tool_input", {}) or {}
    target = inp.get("file_path") or inp.get("path") or inp.get("command") or ""
    if not is_admin_path(target):
        return {}
    if tool not in {"Edit", "Write", "MultiEdit", "NotebookEdit", "Bash"}:
        return {}

    att = find_attestation()
    if att is None:
        msg = ("[admin-design-gate] BLOCKED: admin route file edit attempted without "
               ".admin-build/runs/<ts>/ssot_attestation.json. "
               "Run `admin-build attest --task <kind>` first, then retry.")
        log("PreToolUse:deny:no-attestation", {"tool": tool, "target": target})
        return {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": msg,
            }
        }

    log("PreToolUse:allow", {"tool": tool, "target": target, "attestation": str(att)})
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "additionalContext": f"attestation present: {att}",
        }
    }


# Quick L1 grep patterns (subset — full set lives in admin-build/verifiers/static-grep.py)
QUICK_GREP = [
    (re.compile(r"\bdark:|\.dark\b|className=\"dark"), "L1 violation: dark mode class detected (Tier 0)"),
    (re.compile(r"SUPABASE_SERVICE_ROLE_KEY|service_role"), "L1 violation: service_role leak in client path"),
    (re.compile(r"shadow-2xl|drop-shadow-\[0_.+_40px\]"), "L1 violation: heavy card shadow"),
    (re.compile(r"focus:outline-none(?!\s+focus-visible:|\s+focus:ring)"), "L1 violation: outline removed without replacement"),
]


def on_post_tool_use(payload: dict) -> dict:
    tool = payload.get("tool_name") or payload.get("tool") or ""
    inp = payload.get("tool_input", {}) or {}
    target = inp.get("file_path") or inp.get("path") or ""
    if not is_admin_path(target):
        return {}
    if tool not in {"Edit", "Write", "MultiEdit", "NotebookEdit"}:
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
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": "[admin-design-gate] quick-grep warning:\n" + "\n".join(hits)
                                 + "\n  full verifier: `admin-build verify` (4-layer)",
        }
    }


def on_stop(payload: dict) -> dict:
    """Block stop if verifier-fail marker exists. Caveat: 8회 cap 가능 — external orchestrator 가 최종 책임."""
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
                           "Address findings and re-run `admin-build verify`.\n" + detail[:500]),
            }
    return {}


DISPATCH = {
    "SessionStart": on_session_start,
    "UserPromptSubmit": on_user_prompt_submit,
    "UserPromptExpansion": on_user_prompt_expansion,
    "PreToolUse": on_pre_tool_use,
    "PostToolUse": on_post_tool_use,
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
        return 0  # no-op for unknown events
    try:
        out = handler(payload) or {}
    except Exception as e:
        log(f"{event}:exception", {"err": str(e)})
        return 0  # never break the host on hook bug
    if out:
        sys.stdout.write(json.dumps(out, ensure_ascii=False))
        sys.stdout.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())
