#!/usr/bin/env bash
# daily-digest.sh — 어제 활동 통합 요약 → Telegram push
# 사용법:
#   daily-digest.sh           Telegram push
#   daily-digest.sh --print   stdout 출력 (테스트/디버그용)

set -uo pipefail

SSOT="$HOME/.config/claude-sync"
LEDGER_DIR="$SSOT/state/activity"
SETTINGS="$HOME/.claude/settings.local.json"

mode="${1:-push}"
yesterday=$(date -v-1d +%Y-%m-%d)

total_sessions=0
total_duration=0
total_commits=0
out=""
out+="📊 어제의 두 맥북 ($yesterday)"$'\n'$'\n'

for ledger in "$LEDGER_DIR"/*.jsonl; do
  [[ -f "$ledger" ]] || continue
  persona=$(basename "$ledger" .jsonl)

  emoji="🏠"
  [[ "$persona" == "회사맥프로" ]] && emoji="💼"

  sessions=$(jq -rs --arg d "$yesterday" \
    '[.[] | select(.type == "session_end" and (.ts | startswith($d)))] | length' \
    "$ledger" 2>/dev/null)
  duration=$(jq -rs --arg d "$yesterday" \
    '[.[] | select(.type == "session_end" and (.ts | startswith($d))) | (.duration_min // 0)] | add // 0' \
    "$ledger" 2>/dev/null)
  commits=$(jq -rs --arg d "$yesterday" \
    '[.[] | select(.type == "session_end" and (.ts | startswith($d))) | (.commits // 0)] | add // 0' \
    "$ledger" 2>/dev/null)

  out+="$emoji $persona · $sessions sessions · ${duration}분 · ${commits} commits"$'\n'
  total_sessions=$(( total_sessions + sessions ))
  total_duration=$(( total_duration + duration ))
  total_commits=$(( total_commits + commits ))
done

out+=$'\n'"총 ${total_duration}분 · ${total_commits} commits"

if [[ "$mode" == "--print" ]]; then
  printf "%s\n" "$out"
else
  if [[ -f "$SETTINGS" ]]; then
    token=$(jq -r '.env.TELEGRAM_TOKEN // empty' "$SETTINGS" 2>/dev/null)
    chat_id=$(jq -r '.env.TELEGRAM_CHAT_ID // empty' "$SETTINGS" 2>/dev/null)
    if [[ -n "$token" && -n "$chat_id" ]]; then
      curl -sS -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        --max-time 5 \
        --data-urlencode "chat_id=${chat_id}" \
        --data-urlencode "text=${out}" \
        >/dev/null 2>&1 || true
    fi
  fi
fi
