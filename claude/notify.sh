#!/usr/bin/env bash
# Claude Code 알림 훅 — macOS / Linux (bash)
# ~/.claude/settings.json 의 hooks.Stop / hooks.Notification 에서 호출된다.
# 환경변수는 settings.json 의 env 블록에서 자동 주입된다.

MAX_LEN=300

# --- stdin JSON 파싱 ---
STDIN_TEXT=$(cat)

LAST_MSG=""
HOOK_MSG=""
HOOK_TITLE=""

if [ -n "$STDIN_TEXT" ]; then
    # python3 우선, 없으면 node 사용
    if command -v python3 &>/dev/null; then
        LAST_MSG=$(echo "$STDIN_TEXT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('last_assistant_message', ''))
except: pass
" 2>/dev/null)
        HOOK_MSG=$(echo "$STDIN_TEXT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if not d.get('last_assistant_message'):
        print(d.get('message', ''))
except: pass
" 2>/dev/null)
        HOOK_TITLE=$(echo "$STDIN_TEXT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('title', ''))
except: pass
" 2>/dev/null)
    elif command -v node &>/dev/null; then
        LAST_MSG=$(echo "$STDIN_TEXT" | node -e "
let d=''; process.stdin.on('data',c=>d+=c).on('end',()=>{
  try{ const o=JSON.parse(d); process.stdout.write(o.last_assistant_message||''); }catch(e){}
});
" 2>/dev/null)
        HOOK_MSG=$(echo "$STDIN_TEXT" | node -e "
let d=''; process.stdin.on('data',c=>d+=c).on('end',()=>{
  try{ const o=JSON.parse(d); if(!o.last_assistant_message) process.stdout.write(o.message||''); }catch(e){}
});
" 2>/dev/null)
        HOOK_TITLE=$(echo "$STDIN_TEXT" | node -e "
let d=''; process.stdin.on('data',c=>d+=c).on('end',()=>{
  try{ const o=JSON.parse(d); process.stdout.write(o.title||''); }catch(e){}
});
" 2>/dev/null)
    fi
fi

# --- 메시지 + 타이틀 결정 ---
if [ -n "$LAST_MSG" ]; then
    MESSAGE="${LAST_MSG:0:$MAX_LEN}"
    [ "${#LAST_MSG}" -gt "$MAX_LEN" ] && MESSAGE="${MESSAGE}..."
    TITLE="Claude Code - Done"
elif [ -n "$HOOK_MSG" ]; then
    MESSAGE="$HOOK_MSG"
    TITLE="${HOOK_TITLE:-Claude Code}"
else
    MESSAGE="Task completed!"
    TITLE="Claude Code"
fi

FULL_MESSAGE="[$TITLE] $MESSAGE"

# --- Telegram DM ---
if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    TG_BODY=$(python3 -c "
import json, sys
print(json.dumps({'chat_id': '$TELEGRAM_CHAT_ID', 'text': sys.argv[1]}))
" "$FULL_MESSAGE" 2>/dev/null || echo "{\"chat_id\":\"$TELEGRAM_CHAT_ID\",\"text\":\"$FULL_MESSAGE\"}")

    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -H "Content-Type: application/json; charset=utf-8" \
        --data-binary "$TG_BODY" \
        --max-time 5 > /dev/null 2>&1 || true
fi

# --- Slack DM ---
if [ -n "$SLACK_BOT_TOKEN" ] && [ -n "$SLACK_USER_ID" ]; then
    SLACK_BODY=$(python3 -c "
import json, sys
print(json.dumps({'channel': '$SLACK_USER_ID', 'text': sys.argv[1]}))
" "$FULL_MESSAGE" 2>/dev/null || echo "{\"channel\":\"$SLACK_USER_ID\",\"text\":\"$FULL_MESSAGE\"}")

    curl -s -X POST "https://slack.com/api/chat.postMessage" \
        -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
        -H "Content-Type: application/json; charset=utf-8" \
        --data-binary "$SLACK_BODY" \
        --max-time 5 > /dev/null 2>&1 || true
fi
