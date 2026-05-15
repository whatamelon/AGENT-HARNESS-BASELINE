#!/usr/bin/env python3
import json, os, shutil, subprocess
from pathlib import Path

def has(cmd, args=("--version",)):
    exe = shutil.which(cmd)
    if not exe:
        return False
    try:
        result = subprocess.run([exe, *args], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return result.returncode in (0, 1)
    except Exception:
        return False

def exists(p):
    return Path(os.path.expanduser(p)).exists()

checks = {
    "node": has("node"),
    "python3": has("python3"),
    "git": has("git"),
    "omx": has("omx"),
    "tmux": has("tmux", ("-V",)),
    "vercel": has("vercel"),
    "codexHooks": exists("~/.codex/hooks.json"),
    "claudeSync": exists("~/.config/claude-sync"),
    "designslopAudit": exists("~/.config/claude-sync/claude/hooks/designslop-audit.py"),
}

mode = "manual"
if checks["python3"] or checks["node"]:
    mode = "portable"
if mode == "portable" and checks["omx"]:
    mode = "workstation"
if mode == "workstation" and checks["tmux"] and checks["codexHooks"] and checks["designslopAudit"]:
    mode = "full"

capabilities = {
    "manual": ["read SKILL.md/templates manually", "produce handoff text only"],
    "portable": ["create/validate run documents", "generate brief, rubric, gates, completion audit", "manual runtime handoff"],
    "workstation": ["portable capabilities", "OMX/Ultragoal artifacts and checkpoints when active goal matches"],
    "full": ["workstation capabilities", "tmux Team execution", "Codex/Claude Stop hook designslop gate", "long-running worker coordination"],
}

blockers = []
if mode == "manual": blockers.append("no node/python3: scripts unavailable; use templates manually")
if not checks["omx"]: blockers.append("omx missing: no Ultragoal/Team runtime")
if not checks["tmux"]: blockers.append("tmux missing: no durable Team panes")
if not checks["designslopAudit"]: blockers.append("designslop audit missing: anti-slop gate unavailable/manual")
if not checks["codexHooks"]: blockers.append("Codex hooks missing: no automatic Stop gate")
if not checks["vercel"]: blockers.append("vercel missing: use another adapter or approved fallback")

print(json.dumps({"mode": mode, "checks": checks, "capabilities": capabilities[mode], "blockers": blockers}, indent=2))
