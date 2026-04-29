#!/usr/bin/env bash
# persona.sh — 머신 페르소나 정의/조회
# 사용법:
#   persona.sh             현재 머신 페르소나 이름
#   persona.sh --json      페르소나 + 색 + 이모지 JSON
#   persona.sh --other     상대 머신 페르소나 이름
#   persona.sh --init      .machine.json 없으면 hostname 기반 자동 생성

set -uo pipefail

SSOT="$HOME/.config/claude-sync"
MACHINE_FILE="$SSOT/.machine.json"

# 테스트에서 hostname 주입 가능
HOSTNAME="${HOSTNAME_OVERRIDE:-$(scutil --get LocalHostName 2>/dev/null || hostname)}"

# 두 페르소나 정의 (단일 진실 원천)
HOME_PERSONA='{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493","label":"집"}'
WORK_PERSONA='{"persona":"회사맥프로","emoji":"💼","color":"#0969DA","label":"일"}'

case "${1:-}" in
  --init)
    if [[ -f "$MACHINE_FILE" ]]; then
      echo "ℹ️  $MACHINE_FILE 이미 존재 — skip" >&2
      exit 0
    fi
    if [[ "$HOSTNAME" == *Pro* ]]; then
      echo "$WORK_PERSONA" > "$MACHINE_FILE"
      echo "✓ 회사맥프로 (hostname '$HOSTNAME' 에 'Pro' 포함)" >&2
    elif [[ "$HOSTNAME" == *Air* ]]; then
      echo "$HOME_PERSONA" > "$MACHINE_FILE"
      echo "✓ 홈맥에어 (hostname '$HOSTNAME' 에 'Air' 포함)" >&2
    else
      echo "$HOME_PERSONA" > "$MACHINE_FILE"
      echo "⚠ 자동 매칭 실패 (hostname '$HOSTNAME') — 홈맥에어 default 사용" >&2
      echo "   다른 페르소나 원하면 $MACHINE_FILE 수동 편집" >&2
    fi
    exit 0
    ;;
  --other)
    [[ -f "$MACHINE_FILE" ]] || { echo "❌ $MACHINE_FILE 없음 — 'persona.sh --init' 먼저" >&2; exit 1; }
    current=$(jq -r '.persona' "$MACHINE_FILE")
    if [[ "$current" == "홈맥에어" ]]; then
      echo "회사맥프로"
    else
      echo "홈맥에어"
    fi
    ;;
  --json)
    [[ -f "$MACHINE_FILE" ]] || { echo "❌ $MACHINE_FILE 없음" >&2; exit 1; }
    cat "$MACHINE_FILE"
    ;;
  ""|--get)
    [[ -f "$MACHINE_FILE" ]] || { echo "❌ $MACHINE_FILE 없음 — 'persona.sh --init' 먼저" >&2; exit 1; }
    jq -r '.persona' "$MACHINE_FILE"
    ;;
  *)
    echo "사용법: persona.sh [--init|--json|--other]" >&2
    exit 1
    ;;
esac
