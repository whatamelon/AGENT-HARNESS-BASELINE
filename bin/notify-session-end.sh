#!/usr/bin/env bash
# notify-session-end.sh — Claude Stop hook 트리거
# 사용법: notify-session-end.sh [cwd]
# 환경: DRY_RUN=1 → Telegram/git push skip

set -uo pipefail

SSOT="$HOME/.config/agent-harness-baseline"
PERSONA_BIN="$SSOT/bin/persona.sh"
LEDGER_DIR="$SSOT/state/activity"
NOTIFY_BIN="$SSOT/bin/notify-activity.sh"
SUMMARIZE_BIN="$SSOT/bin/summarize-session.sh"

cwd="${1:-$PWD}"
persona=$("$PERSONA_BIN" 2>/dev/null) || exit 0
ledger="$LEDGER_DIR/$persona.jsonl"
[[ -f "$ledger" ]] || exit 0

# 마지막 session_start 의 ts
last_start=$(jq -r 'select(.type == "session_start") | .ts' "$ledger" 2>/dev/null | tail -1)
if [[ -z "$last_start" || "$last_start" == "null" ]]; then
  # spec fallback: -10분 default (session_start producer 없는 환경)
  start_epoch=$(( $(date +%s) - 600 ))
else
  date_part="${last_start%%T*}"
  time_part="${last_start#*T}"
  hms="${time_part:0:8}"
  tz_raw="${time_part:8}"
  tz_compact="${tz_raw//:/}"
  start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "${date_part}T${hms}${tz_compact}" +%s 2>/dev/null || echo $(( $(date +%s) - 600 )))
fi
now_epoch=$(date +%s)
duration_min=$(( (now_epoch - start_epoch) / 60 ))

# 그 사이 commits 카운트 (last_start 이후)
if [[ -n "$last_start" && "$last_start" != "null" ]]; then
  commits=$(jq -r --arg t "$last_start" \
    'select(.type == "commit" and .ts >= $t) | .sha' \
    "$ledger" 2>/dev/null | wc -l | tr -d ' ')
else
  commits=0
fi

files_changed=0

# 의미 있는 세션 판단
if (( duration_min < 3 && commits < 1 )); then
  exit 0
fi

# 헤드라인 합성
summary=$("$SUMMARIZE_BIN" "$cwd" "$duration_min" "$commits" "$files_changed" 2>/dev/null \
  || echo "$cwd · ${duration_min}분")

# notify-activity 호출 (DRY_RUN 환경변수 그대로 위임)
"$NOTIFY_BIN" session_end \
  "cwd=$cwd" \
  "duration_min=$duration_min" \
  "commits=$commits" \
  "files_changed=$files_changed" \
  "summary=$summary" || true
