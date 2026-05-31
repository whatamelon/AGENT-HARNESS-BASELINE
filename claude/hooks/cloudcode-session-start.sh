#!/usr/bin/env bash
# cloudcode-session-start — register this tab + inject sibling discovery
# context using the Phase 1 atomic registry.
#
# Hook event: SessionStart (Claude Code).
# Behavior:
#   1. Read Claude hook input JSON from stdin (sessionId, cwd, ...).
#   2. workspace.tab.register {tab_id, window_id, cwd, agent_pid}.
#   3. workspace.tab.list → enumerate sibling registered tabs.
#   4. workspace.lease.list → flag active cross-tab locks.
#   5. Emit `hookSpecificOutput.additionalContext`.
#   6. Fail-open: socket missing / rpc absent → exit 0 silently.

set -u

raw_input="$(cat 2>/dev/null || true)"
command -v cloudcode-rpc >/dev/null 2>&1 || exit 0

self_ws="${CLOUDCODE_WORKSPACE_ID:-}"
self_sf="${CLOUDCODE_SURFACE_ID:-}"

self_cwd="$(printf '%s' "$raw_input" | python3 /dev/fd/3 3<<'PY' 2>/dev/null || true
import json, sys
try: print(json.load(sys.stdin).get('cwd', ''))
except Exception: pass
PY
)"

# 1. Register this tab (no-op when self_ws is empty; e.g. Claude outside CloudCode)
if [ -n "$self_ws" ]; then
  reg_req=$(python3 -c "
import json, os, sys
print(json.dumps({
    'id': 'reg',
    'method': 'workspace.tab.register',
    'params': {
        'tab_id': sys.argv[1],
        'window_id': os.environ.get('CLOUDCODE_WINDOW_ID', ''),
        'cwd': sys.argv[2] or '',
        'agent_pid': int(os.environ.get('CLAUDE_PARENT_PID', os.getpid())),
    },
}))" "$self_ws" "$self_cwd" 2>/dev/null)
  [ -n "$reg_req" ] && printf '%s\n' "$reg_req" \
    | cloudcode-rpc >/dev/null 2>&1 || true
fi

# 2. Fetch tabs from the Phase 1 registry.
tabs_resp="$(printf '%s\n' \
  '{"id":"tabs","method":"workspace.tab.list","params":{}}' \
  | cloudcode-rpc 2>/dev/null || true)"
[ -z "$tabs_resp" ] && exit 0

# 3. Fetch active leases (informational only — won't block)
leases_resp="$(printf '%s\n' \
  '{"id":"leases","method":"workspace.lease.list","params":{}}' \
  | cloudcode-rpc 2>/dev/null || true)"

python3 /dev/fd/3 3<<PY 2>/dev/null || exit 0
import json, sys

tabs_raw = """$tabs_resp"""
leases_raw = """$leases_resp"""
self_ws = "$self_ws"
self_sf = "$self_sf"
self_cwd = "$self_cwd"

def find_response(raw, ids):
    """Return the parsed result dict whose id is in `ids`, or None."""
    for line in raw.splitlines():
        line = line.strip()
        if not line.startswith('{'):
            continue
        try:
            obj = json.loads(line)
        except Exception:
            continue
        if not isinstance(obj, dict):
            continue
        if obj.get('id') not in ids or obj.get('ok') is not True:
            continue
        return obj.get('result') or {}
    return {}

tabs_payload = find_response(tabs_raw, {'tabs'})
leases_payload = find_response(leases_raw, {'leases'})

tabs = tabs_payload.get('tabs') or []
leases = leases_payload.get('leases') or []

if not tabs:
    sys.exit(0)

lines = []
lines.append(
    f"[CloudCode] This tab: workspace_id={self_ws or 'unknown'} "
    f"surface_id={self_sf or 'unknown'} cwd={self_cwd or '?'}"
)
lines.append(
    f"[CloudCode] {len(tabs)} workspace tab(s) in window. "
    "Phase 1 atomic lease enforced via PreToolUse hook."
)
for t in tabs:
    if not isinstance(t, dict):
        continue
    tid = str(t.get('id') or '?')
    title = t.get('title') or ''
    task = t.get('current_task') or ''
    cwd = t.get('cwd') or ''
    mark = " <— this tab" if tid == self_ws else ""
    parts = [title]
    if task: parts.append(f"task={task}")
    if cwd: parts.append(f"cwd={cwd}")
    detail = " ".join(p for p in parts if p)
    lines.append(f"  • {tid[:8]}… {detail}{mark}")

if leases:
    lines.append(f"[CloudCode] {len(leases)} active lease(s):")
    for l in leases:
        if not isinstance(l, dict):
            continue
        owner = str(l.get('owner_tab_id') or '?')[:8]
        path = l.get('path') or '?'
        lines.append(f"  · {owner}… holds {path}")

payload = {
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": "\n".join(lines),
    }
}
sys.stdout.write(json.dumps(payload))
PY

exit 0
