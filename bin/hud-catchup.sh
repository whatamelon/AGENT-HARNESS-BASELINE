#!/usr/bin/env bash
# hud-catchup.sh — 4시간+ 휴면 후 어제 활동 표시
# zsh precmd 가 매 prompt 호출. 매 호출 마지막에 last-prompt-ts.txt 갱신.

set -uo pipefail

SSOT="$HOME/.config/agent-harness-baseline"
PERSONA_BIN="$SSOT/bin/persona.sh"
LEDGER_DIR="$SSOT/state/activity"
TS_FILE="$SSOT/state/last-prompt-ts.txt"

mkdir -p "$(dirname "$TS_FILE")"
now_epoch=$(date +%s)

if [[ ! -f "$TS_FILE" ]]; then
  echo "$now_epoch" > "$TS_FILE"
  exit 0
fi

last_epoch=$(cat "$TS_FILE" 2>/dev/null || echo 0)
diff=$(( now_epoch - last_epoch ))

# ts 갱신
echo "$now_epoch" > "$TS_FILE"

# 4시간(14400s) 미만 → silent
if (( diff < 14400 )); then
  exit 0
fi

# 4시간+ 휴면
hours=$(( diff / 3600 ))
self_json=$("$PERSONA_BIN" --json 2>/dev/null) || exit 0
self=$(echo "$self_json" | jq -r '.persona')
self_emoji=$(echo "$self_json" | jq -r '.emoji')
other=$("$PERSONA_BIN" --other 2>/dev/null) || exit 0
other_emoji="💼"
[[ "$self" == "회사맥프로" ]] && other_emoji="🏠"

echo "$self_emoji $self 깨어남 (${hours}시간 만에)"
echo ""

# 상대 머신의 휴면 사이 활동 (last_epoch 이후)
since_iso=$(date -r "$last_epoch" +%Y-%m-%dT%H:%M:%S%z 2>/dev/null | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
other_ledger="$LEDGER_DIR/$other.jsonl"

if [[ -f "$other_ledger" ]]; then
  echo "$other_emoji $other 한 일:"
  jq -r --arg since "$since_iso" \
    'select(.type == "session_end" and .ts >= $since) |
     "  • \(.cwd // "?") · \(.duration_min // "?")분" + (if .summary then " · \"\(.summary)\"" else "" end)' \
    "$other_ledger" 2>/dev/null | head -5

  other_commits=$(jq -r --arg since "$since_iso" \
    'select(.type == "commit" and .ts >= $since) | .sha' \
    "$other_ledger" 2>/dev/null | wc -l | tr -d ' ')
  if (( other_commits > 0 )); then
    echo "  • 그 외 commit ${other_commits}개"
  fi

  has_activity=$(jq -r --arg since "$since_iso" \
    'select(.ts >= $since) | .ts' "$other_ledger" 2>/dev/null | head -1)
  if [[ -z "$has_activity" ]]; then
    echo "  (활동 없음)"
  fi
fi
