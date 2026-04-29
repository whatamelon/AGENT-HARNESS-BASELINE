#!/usr/bin/env bash
# notify-activity.sh — 활동 발생 시 3채널 동시 발사
#   1. ledger.jsonl append
#   2. Telegram push (best effort)
#   3. git push --immediate (백그라운드)
#
# 사용법:
#   notify-activity.sh <event_type> [key=value]...
# 예:
#   notify-activity.sh session_end cwd=/dev/lawblaw duration_min=22 commits=3
#
# 환경 변수:
#   DRY_RUN=1   3채널 모두 skip (테스트용)

set -uo pipefail

SSOT="$HOME/.config/claude-sync"
LEDGER_BIN="$SSOT/bin/ledger-append.sh"
SYNC_BIN="$SSOT/bin/sync.sh"
PERSONA_BIN="$SSOT/bin/persona.sh"
SETTINGS="$HOME/.claude/settings.local.json"

# Telegram 메시지 포맷 (단위 테스트용 함수)
format_telegram_message() {
  local event="$1" cwd="${2:-}" duration="${3:-}" commits="${4:-}"
  local persona_json
  persona_json=$("$PERSONA_BIN" --json 2>/dev/null) || return 1
  local persona emoji
  persona=$(echo "$persona_json" | jq -r '.persona')
  emoji=$(echo "$persona_json" | jq -r '.emoji')

  case "$event" in
    session_end)
      printf "%s *%s* · 작업 끝\n📂 %s\n⏱ %s · 📝 %s" \
        "$emoji" "$persona" "$cwd" "$duration" "$commits"
      ;;
    session_start)
      printf "%s *%s* · 시작\n📂 %s" "$emoji" "$persona" "$cwd"
      ;;
    *)
      printf "%s *%s* · %s" "$emoji" "$persona" "$event"
      ;;
  esac
}

send_telegram() {
  local text="$1"
  [[ -f "$SETTINGS" ]] || return 0
  local token chat_id
  token=$(jq -r '.env.TELEGRAM_TOKEN // empty' "$SETTINGS" 2>/dev/null)
  chat_id=$(jq -r '.env.TELEGRAM_CHAT_ID // empty' "$SETTINGS" 2>/dev/null)
  [[ -n "$token" && -n "$chat_id" ]] || return 0
  curl -sS -X POST "https://api.telegram.org/bot${token}/sendMessage" \
    --max-time 5 \
    --data-urlencode "chat_id=${chat_id}" \
    --data-urlencode "text=${text}" \
    >/dev/null 2>&1 || true
}

# --source-only 모드 (테스트가 함수만 가져올 때)
if [[ "${1:-}" == "--source-only" ]]; then
  return 0 2>/dev/null || exit 0
fi

if [[ $# -lt 1 || -z "${1:-}" ]]; then
  echo "사용법: notify-activity.sh <event_type> [key=value]..." >&2
  exit 1
fi

event_type="$1"
shift

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  exit 0
fi

# (1) ledger append
"$LEDGER_BIN" "$event_type" "$@" || true

# (2) Telegram push (key=value 추출해서 헤드라인 합성)
cwd="" duration="" commits=""
for pair in "$@"; do
  case "$pair" in
    cwd=*)          cwd="${pair#cwd=}" ;;
    duration_min=*) duration="${pair#duration_min=}m" ;;
    commits=*)      commits="${pair#commits=}" ;;
  esac
done
text=$(format_telegram_message "$event_type" "$cwd" "$duration" "$commits" 2>/dev/null || true)
[[ -n "${text:-}" ]] && send_telegram "$text"

# (3) git push --immediate (백그라운드)
"$SYNC_BIN" --immediate >/dev/null 2>&1 &
disown $! 2>/dev/null || true
