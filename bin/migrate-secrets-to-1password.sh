#!/usr/bin/env bash
# migrate-secrets-to-1password.sh
# settings.local.json의 평문 토큰을 1Password vault로 옮기고,
# settings.local.json을 op://... 참조 버전으로 교체.
#
# 사용법: ./migrate-secrets-to-1password.sh <VAULT_NAME>
# 예시:   ./migrate-secrets-to-1password.sh Employee

set -euo pipefail

VAULT="${1:-}"
if [[ -z "$VAULT" ]]; then
  echo "사용법: $0 <VAULT_NAME>"
  echo ""
  echo "사용 가능한 vault:"
  op vault list
  exit 1
fi

LOCAL=~/.claude/settings.local.json
[[ -f "$LOCAL" ]] || { echo "❌ $LOCAL 없음"; exit 1; }

# vault 존재 확인
op vault get "$VAULT" >/dev/null 2>&1 || { echo "❌ vault '$VAULT' 없음"; op vault list; exit 1; }

echo "▶ vault: $VAULT"
echo ""

# 평문 토큰 추출
TG_TOKEN=$(jq -r '.env.TELEGRAM_TOKEN // empty' "$LOCAL")
TG_CHAT=$(jq -r '.env.TELEGRAM_CHAT_ID // empty' "$LOCAL")
SLACK_TOKEN=$(jq -r '.env.SLACK_BOT_TOKEN // empty' "$LOCAL")
SLACK_USER=$(jq -r '.env.SLACK_USER_ID // empty' "$LOCAL")

# 헬퍼: 항목 있으면 업데이트, 없으면 생성
upsert_item() {
  local title="$1"; shift
  if op item get "$title" --vault="$VAULT" >/dev/null 2>&1; then
    echo "  • '$title' 이미 존재 — 업데이트"
    op item edit "$title" --vault="$VAULT" "$@" >/dev/null
  else
    echo "  • '$title' 신규 생성"
    op item create --category=login --vault="$VAULT" --title="$title" \
      username="claude-code" "$@" >/dev/null
  fi
}

echo "▶ Telegram Bot 항목"
if [[ -n "$TG_TOKEN" && -n "$TG_CHAT" ]]; then
  upsert_item "Claude-Telegram-Bot" \
    "password=$TG_TOKEN" \
    "chat-id[text]=$TG_CHAT"
else
  echo "  ⚠ TELEGRAM_TOKEN/TELEGRAM_CHAT_ID 비어있음 — 스킵"
fi
echo ""

echo "▶ Slack Bot 항목"
if [[ -n "$SLACK_TOKEN" && -n "$SLACK_USER" ]]; then
  upsert_item "Claude-Slack-Bot" \
    "password=$SLACK_TOKEN" \
    "user-id[text]=$SLACK_USER"
else
  echo "  ⚠ SLACK_BOT_TOKEN/SLACK_USER_ID 비어있음 — 스킵"
fi
echo ""

echo "▶ 새 settings.local.json 작성 (op:// 참조 버전)"
TMPL=$(mktemp)
cat > "$TMPL" <<EOF
{
  "env": {
    "TELEGRAM_TOKEN": "{{ op://${VAULT}/Claude-Telegram-Bot/password }}",
    "TELEGRAM_CHAT_ID": "{{ op://${VAULT}/Claude-Telegram-Bot/chat-id }}",
    "SLACK_BOT_TOKEN": "{{ op://${VAULT}/Claude-Slack-Bot/password }}",
    "SLACK_USER_ID": "{{ op://${VAULT}/Claude-Slack-Bot/user-id }}"
  }
}
EOF

# op inject로 평문 채워서 settings.local.json 재생성
op inject --force -i "$TMPL" -o "$LOCAL"
chmod 600 "$LOCAL"
rm "$TMPL"

echo "  ✓ $LOCAL 업데이트 (1Password에서 값 주입됨)"
echo ""

echo "▶ settings.local.tpl.json 도 만들어둠 (재주입용 템플릿)"
TPL=~/.claude/settings.local.tpl.json
cat > "$TPL" <<EOF
{
  "env": {
    "TELEGRAM_TOKEN": "{{ op://${VAULT}/Claude-Telegram-Bot/password }}",
    "TELEGRAM_CHAT_ID": "{{ op://${VAULT}/Claude-Telegram-Bot/chat-id }}",
    "SLACK_BOT_TOKEN": "{{ op://${VAULT}/Claude-Slack-Bot/password }}",
    "SLACK_USER_ID": "{{ op://${VAULT}/Claude-Slack-Bot/user-id }}"
  }
}
EOF
chmod 600 "$TPL"
echo "  ✓ $TPL — 다음번엔 'op inject -i $TPL -o $LOCAL' 한 줄로 재주입"
echo ""

echo "▶ install.sh로 settings.json 재머지"
~/.config/agent-harness-baseline/bin/install.sh > /dev/null
echo "  ✓ ~/.claude/settings.json 머지 완료"
echo ""

echo "▶ 검증: settings.json의 env 값 확인 (앞 10자만 노출)"
jq -r '.env | to_entries[] | "  \(.key): \(.value[0:10])..."' ~/.claude/settings.json
echo ""

echo "✅ 마이그레이션 완료. 1Password에 다음 항목들이 만들어짐:"
echo "  - $VAULT/Claude-Telegram-Bot (password=token, chat-id=chat ID)"
echo "  - $VAULT/Claude-Slack-Bot (password=token, user-id=user ID)"
echo ""
echo "이제 settings.local.json의 평문 토큰은 사라졌고 op:// 참조로 대체됨."
echo "하지만 settings.json (머지 결과)은 여전히 평문 — Claude Code가 읽을 때 필요해서."
echo "settings.json은 gitignore라 push 안 됨 (안전)."
