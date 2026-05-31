#!/usr/bin/env bash
# cloudcode-user-prompt — heartbeat this tab with the current Claude task so
# sibling tabs can observe what each agent is working on.
#
# Hook event: UserPromptSubmit.
# Behavior:
#   1. Read Claude hook input JSON from stdin.
#   2. Extract prompt → trim + collapse whitespace + cap to ~120 chars.
#   3. workspace.tab.heartbeat {tab_id, current_task=<trimmed>}.
#   4. Fail-open. Always exit 0.

set -u

raw_input="$(cat 2>/dev/null || true)"
command -v cloudcode-rpc >/dev/null 2>&1 || exit 0

self_ws="${CLOUDCODE_WORKSPACE_ID:-}"
[ -z "$self_ws" ] && exit 0

current_task="$(printf '%s' "$raw_input" | python3 /dev/fd/3 3<<'PY' 2>/dev/null || true
import json, re, sys
try:
    obj = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
prompt = obj.get("prompt") or ""
prompt = re.sub(r"\s+", " ", prompt).strip()
if not prompt:
    sys.exit(0)
# Redact secret-shaped tokens before persisting to the shared sidebar so
# sibling tabs do not see a credential pasted into another prompt. Patterns
# are intentionally narrow to avoid false positives.
patterns = [
    r"(?i)(sk-[A-Za-z0-9_-]{20,})",                   # OpenAI / Anthropic tokens
    r"(?i)(ghp_[A-Za-z0-9]{30,})",                    # GitHub PATs
    r"(?i)(xox[abp]-[A-Za-z0-9-]{10,})",              # Slack tokens
    r"(?i)(AKIA[0-9A-Z]{16})",                        # AWS access keys
    r"(?i)([A-Za-z0-9+/=]{40,})",                     # generic long base64-ish
]
for p in patterns:
    prompt = re.sub(p, "<redacted>", prompt)
prompt = prompt[:120]
prompt = re.sub(r"[\x00-\x1f]", "", prompt)
print(prompt)
PY
)"

[ -z "$current_task" ] && exit 0

req=$(python3 -c "
import json, sys
print(json.dumps({
    'id': 'user-prompt',
    'method': 'workspace.tab.heartbeat',
    'params': {'tab_id': sys.argv[1], 'current_task': sys.argv[2]},
}))" "$self_ws" "$current_task" 2>/dev/null)

[ -n "$req" ] && printf '%s\n' "$req" | cloudcode-rpc >/dev/null 2>&1 || true

exit 0
