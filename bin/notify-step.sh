#!/usr/bin/env bash
# notify-step.sh — Telegram editMessageText 라이브 progress
# 사용법:
#   notify-step.sh start <total>
#   notify-step.sh update <current> <total> <status_emoji> <step_name> [elapsed]
#   notify-step.sh done <total> [elapsed]
#   notify-step.sh human-action <step_name> <action_text>
#   notify-step.sh reset
#
# 환경:
#   DRY_RUN=1   외부 호출 skip
#
# 메시지 ID 보존: state/wizard-message-id.txt

set -uo pipefail

SSOT="$HOME/.config/agent-harness-baseline"
PERSONA_BIN="$SSOT/bin/persona.sh"
SETTINGS="$HOME/.claude/settings.local.json"
MSG_ID_FILE="$SSOT/state/wizard-message-id.txt"

# Progress bar (▓▓▓▓░░░░░░░░░ 패턴, 13 chars)
build_progress_bar() {
  local current="$1" total="$2"
  local filled=$(( current * 13 / total ))
  (( filled > 13 )) && filled=13
  (( filled < 0 )) && filled=0
  local empty=$(( 13 - filled ))
  local bar=""
  local i
  for ((i=0; i<filled; i++)); do bar+="▓"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  printf "%s" "$bar"
}

# 진행 중 메시지 (페르소나 + 진행률 + 단계명)
build_progress_message() {
  local current="$1" total="$2" status="$3" step_name="$4" elapsed="${5:-}"
  local persona_json
  persona_json=$("$PERSONA_BIN" --json 2>/dev/null) || return 1
  local persona emoji
  persona=$(echo "$persona_json" | jq -r '.persona')
  emoji=$(echo "$persona_json" | jq -r '.emoji')

  local pct=$(( current * 100 / total ))
  local bar
  bar=$(build_progress_bar "$current" "$total")

  if [[ -n "$elapsed" ]]; then
    printf "%s %s 셋업 중...\n\n%s %d/%d · %d%%\n\n%s %s\n⏱ %s" \
      "$emoji" "$persona" \
      "$bar" "$current" "$total" "$pct" \
      "$status" "$step_name" \
      "$elapsed"
  else
    printf "%s %s 셋업 중...\n\n%s %d/%d · %d%%\n\n%s %s" \
      "$emoji" "$persona" \
      "$bar" "$current" "$total" "$pct" \
      "$status" "$step_name"
  fi
}

# 완료 메시지
build_done_message() {
  local total="$1" elapsed="${2:-}"
  local persona_json
  persona_json=$("$PERSONA_BIN" --json 2>/dev/null) || return 1
  local persona emoji
  persona=$(echo "$persona_json" | jq -r '.persona')
  emoji=$(echo "$persona_json" | jq -r '.emoji')

  local bar
  bar=$(build_progress_bar "$total" "$total")
  if [[ -n "$elapsed" ]]; then
    printf "🎉 %s %s 셋업 완료!\n\n%s %d/%d · 100%%\n\n⏱ %s\n\n🚀 다음: ahb-doctor" \
      "$emoji" "$persona" \
      "$bar" "$total" "$total" \
      "$elapsed"
  else
    printf "🎉 %s %s 셋업 완료!\n\n%s %d/%d · 100%%\n\n🚀 다음: ahb-doctor" \
      "$emoji" "$persona" \
      "$bar" "$total" "$total"
  fi
}

# 사람 액션 별도 메시지
build_human_action_message() {
  local step_name="$1" action_text="$2"
  printf "🔐 너의 손이 필요해\n\n[%s]\n\n%s" "$step_name" "$action_text"
}

# Telegram sendMessage (반환: message_id)
telegram_send() {
  local text="$1"
  [[ -f "$SETTINGS" ]] || return 0
  local token chat_id
  token=$(jq -r '.env.TELEGRAM_TOKEN // empty' "$SETTINGS" 2>/dev/null)
  chat_id=$(jq -r '.env.TELEGRAM_CHAT_ID // empty' "$SETTINGS" 2>/dev/null)
  [[ -n "$token" && -n "$chat_id" ]] || return 0
  local response
  response=$(curl -sS -X POST "https://api.telegram.org/bot${token}/sendMessage" \
    --max-time 5 \
    --data-urlencode "chat_id=${chat_id}" \
    --data-urlencode "text=${text}" \
    2>/dev/null) || return 0
  echo "$response" | jq -r '.result.message_id // empty' 2>/dev/null
}

# Telegram editMessageText
telegram_edit() {
  local message_id="$1" text="$2"
  [[ -f "$SETTINGS" ]] || return 0
  local token chat_id
  token=$(jq -r '.env.TELEGRAM_TOKEN // empty' "$SETTINGS" 2>/dev/null)
  chat_id=$(jq -r '.env.TELEGRAM_CHAT_ID // empty' "$SETTINGS" 2>/dev/null)
  [[ -n "$token" && -n "$chat_id" && -n "$message_id" ]] || return 0
  curl -sS -X POST "https://api.telegram.org/bot${token}/editMessageText" \
    --max-time 5 \
    --data-urlencode "chat_id=${chat_id}" \
    --data-urlencode "message_id=${message_id}" \
    --data-urlencode "text=${text}" \
    >/dev/null 2>&1 || true
}

# --source-only 모드 (테스트가 함수만 가져올 때)
if [[ "${1:-}" == "--source-only" ]]; then
  return 0 2>/dev/null || exit 0
fi

[[ "${DRY_RUN:-0}" == "1" ]] && exit 0

mkdir -p "$(dirname "$MSG_ID_FILE")"

case "${1:-}" in
  start)
    total="${2:-13}"
    text=$(build_progress_message 0 "$total" "⏳" "시작 중..." "")
    msg_id=$(telegram_send "$text")
    [[ -n "$msg_id" ]] && echo "$msg_id" > "$MSG_ID_FILE"
    ;;
  update)
    current="${2:-0}"
    # 방어: 숫자만 허용 (예: "13b" → "13")
    current=$(echo "$current" | grep -oE '^[0-9]+' | head -1)
    current="${current:-0}"
    total="${3:-13}"
    status="${4:-🔄}"
    step_name="${5:-}"
    elapsed="${6:-}"
    msg_id=""
    [[ -f "$MSG_ID_FILE" ]] && msg_id=$(cat "$MSG_ID_FILE")
    text=$(build_progress_message "$current" "$total" "$status" "$step_name" "$elapsed")
    if [[ -n "$msg_id" ]]; then
      telegram_edit "$msg_id" "$text"
    else
      msg_id=$(telegram_send "$text")
      [[ -n "$msg_id" ]] && echo "$msg_id" > "$MSG_ID_FILE"
    fi
    ;;
  done)
    total="${2:-13}"
    elapsed="${3:-}"
    msg_id=""
    [[ -f "$MSG_ID_FILE" ]] && msg_id=$(cat "$MSG_ID_FILE")
    text=$(build_done_message "$total" "$elapsed")
    if [[ -n "$msg_id" ]]; then
      telegram_edit "$msg_id" "$text"
    else
      telegram_send "$text" >/dev/null
    fi
    ;;
  human-action)
    step_name="${2:-?}"
    action_text="${3:-}"
    text=$(build_human_action_message "$step_name" "$action_text")
    telegram_send "$text" >/dev/null
    ;;
  reset)
    rm -f "$MSG_ID_FILE"
    ;;
  *)
    echo "사용법: notify-step.sh {start|update|done|human-action|reset} ..." >&2
    exit 1
    ;;
esac
