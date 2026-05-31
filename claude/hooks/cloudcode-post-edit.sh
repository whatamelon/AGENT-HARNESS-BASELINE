#!/usr/bin/env bash
# cloudcode-post-edit — release atomic lease via workspace.lease.release (Phase 1).
#
# Hook event: PostToolUse with matcher Edit|Write|MultiEdit.
# Behavior:
#   1. Parse stdin Claude hook input → tool_input.file_path.
#   2. workspace.lease.release {path, tab_id=CLOUDCODE_WORKSPACE_ID}.
#   3. workspace.tab.heartbeat to keep this tab alive in the registry.
#   4. Fail-open. Always exit 0.

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

if [ -n "$target" ]; then
  release_req=$(python3 -c "
import json, sys
print(json.dumps({
    'id': 'post-edit-release',
    'method': 'workspace.lease.release',
    'params': {'path': sys.argv[1], 'tab_id': sys.argv[2]},
}))" "$target" "$self_ws" 2>/dev/null)
  [ -n "$release_req" ] && \
    printf '%s\n' "$release_req" | cloudcode-rpc >/dev/null 2>&1 || true
fi

hb_req=$(python3 -c "
import json, sys
print(json.dumps({
    'id': 'post-edit-heartbeat',
    'method': 'workspace.tab.heartbeat',
    'params': {'tab_id': sys.argv[1]},
}))" "$self_ws" 2>/dev/null)
[ -n "$hb_req" ] && \
  printf '%s\n' "$hb_req" | cloudcode-rpc >/dev/null 2>&1 || true

exit 0
