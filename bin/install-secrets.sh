#!/usr/bin/env bash
# install-secrets.sh — 1Password에서 머신 env secret 가져와 ~/.claude/settings.local.json에 주입.
#
# 사용:
#   install-secrets             # 멱등 실행 (재실행 안전)
#   install-secrets --dry-run   # 평가 결과만 보고 디스크 안 씀
#
# 동작:
#   1. SSOT/claude/settings.local.example.json (op:// template) 평가
#   2. 기존 ~/.claude/settings.local.json의 다른 키 (permissions 등) 보존
#   3. 머지해서 ~/.claude/settings.local.json 작성, 0600 권한

set -euo pipefail

readonly SSOT="$HOME/.config/claude-sync"
readonly TPL="$SSOT/claude/settings.local.example.json"
readonly TARGET="$HOME/.claude/settings.local.json"

readonly G='\033[0;32m'; readonly Y='\033[1;33m'; readonly R='\033[0;31m'; readonly N='\033[0m'

DRY=0
for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY=1 ;;
    -h|--help)
      sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "❌ 알 수 없는 옵션: $arg"; exit 1 ;;
  esac
done

# 의존성 검사
command -v op >/dev/null || { echo -e "${R}❌ 1Password CLI (op) 미설치${N}"; exit 1; }
command -v jq >/dev/null || { echo -e "${R}❌ jq 미설치${N}"; exit 1; }
[[ -f "$TPL" ]] || { echo -e "${R}❌ 템플릿 없음: $TPL${N}"; exit 1; }

# 1Password 로그인 상태
if ! op vault list >/dev/null 2>&1; then
  echo -e "${Y}⚠ 1Password 미로그인 — 'op signin' 후 재시도${N}"
  exit 1
fi

# op inject로 평가
TMP_EVAL=$(mktemp -t claude-secrets.XXXXXX.json)
trap 'rm -f "$TMP_EVAL"' EXIT

if ! op inject -i "$TPL" -o "$TMP_EVAL" --force 2>/dev/null; then
  echo -e "${R}❌ op inject 실패 — vault/item/field 확인${N}"
  echo "   템플릿: $TPL"
  exit 1
fi

# 평가 결과가 유효 JSON인지 확인
if ! jq empty "$TMP_EVAL" 2>/dev/null; then
  echo -e "${R}❌ 평가 결과가 유효 JSON 아님${N}"
  exit 1
fi

# Dry-run 모드
if [[ "$DRY" == "1" ]]; then
  echo -e "${G}▶ 평가 결과 (dry-run, 디스크 안 씀)${N}"
  # secret 마스킹 출력
  jq 'with_entries(.value |= (if type == "object" then
        with_entries(.value |= (if . == "" then "" else "[MASKED]" end))
      else . end))' "$TMP_EVAL"
  exit 0
fi

# 기존 settings.local.json 백업 + 머지
mkdir -p "$HOME/.claude"
if [[ -f "$TARGET" ]]; then
  BACKUP="${TARGET}.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$TARGET" "$BACKUP"
  echo -e "${G}▶${N} 백업: $BACKUP"

  # 기존 + 새 env 머지 (새 env가 기존 env 덮어씀, 다른 키는 보존)
  TMP_MERGED=$(mktemp -t claude-merged.XXXXXX.json)
  jq -s '.[0] * .[1]' "$TARGET" "$TMP_EVAL" > "$TMP_MERGED"
  mv "$TMP_MERGED" "$TARGET"
else
  echo -e "${Y}⚠${N} ~/.claude/settings.local.json 없음 — 새로 생성"
  cp "$TMP_EVAL" "$TARGET"
fi

chmod 600 "$TARGET"
echo -e "${G}✓${N} $TARGET 업데이트 (env 4개 주입, permissions 보존)"
