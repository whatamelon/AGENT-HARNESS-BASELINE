#!/usr/bin/env bash
# cloudcode-pre-edit — atomic lease check via workspace.lease.acquire (Phase 1).
#
# Hook event: PreToolUse with matcher Edit|Write|MultiEdit.
# Behavior:
#   1. Parse stdin Claude hook input → tool_input.file_path.
#   2. Resolve absolute path.
#   3. Issue workspace.lease.acquire {path, tab_id=CLOUDCODE_WORKSPACE_ID, ttl=300}.
#   4. Outcome "held_by_other" → exit 2 with blocking message (Claude denies tool).
#      Outcome "acquired" or "already_owned" → exit 0 (proceed).
#   5. Fail-open when socket / cloudcode-rpc unavailable or host doesn't
#      support the V2 method yet.

set -u

raw_input="$(cat 2>/dev/null || true)"
command -v cloudcode-rpc >/dev/null 2>&1 || exit 0

self_ws="${CLOUDCODE_WORKSPACE_ID:-}"
[ -z "$self_ws" ] && exit 0

target="$(printf '%s' "$raw_input" | python3 /dev/fd/3 3<<'PY' 2>/dev/null || true
import json, os, sys
try:
    obj = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
ti = obj.get("tool_input") or {}
p = ti.get("file_path") or ti.get("notebook_path") or ""
if not p:
    sys.exit(0)
print(os.path.abspath(os.path.expanduser(p)))
PY
)"
[ -z "$target" ] && exit 0

req=$(python3 -c "
import json, sys
print(json.dumps({
    'id': 'pre-edit',
    'method': 'workspace.lease.acquire',
    'params': {
        'path': sys.argv[1],
        'tab_id': sys.argv[2],
        'ttl_seconds': 300,
        'intent': 'edit',
    },
}))" "$target" "$self_ws" 2>/dev/null)

[ -z "$req" ] && exit 0

resp="$(printf '%s\n' "$req" | cloudcode-rpc 2>/dev/null || true)"
[ -z "$resp" ] && exit 0

verdict=$(python3 /dev/fd/3 3<<PY 2>/dev/null
import json, sys
target = "$target"
data = """$resp"""
for line in data.splitlines():
    line = line.strip()
    if not line.startswith('{'):
        continue
    try:
        obj = json.loads(line)
    except Exception:
        continue
    if not (isinstance(obj, dict) and obj.get('id') == 'pre-edit'):
        continue
    if obj.get('ok') is True:
        result = obj.get('result') or {}
        outcome = result.get('outcome')
        owner = result.get('owner_tab_id') or ''
        if outcome == 'held_by_other':
            print(f"BLOCKED\t{owner}")
        else:
            print('OK')
    else:
        err = obj.get('error') or {}
        # method_not_found => host pre-Phase1, treat as fail-open.
        if err.get('code') == 'method_not_found':
            print('FALLBACK')
        else:
            print('FALLBACK')
    break
PY
)

case "$verdict" in
  BLOCKED*)
    other="$(printf '%s' "$verdict" | awk -F'\t' '{print $2}')"
    echo "[CloudCode lease] $target is being edited by workspace ${other:-<unknown>}. Wait or coordinate." >&2
    exit 2
    ;;
  *)
    exit 0
    ;;
esac
