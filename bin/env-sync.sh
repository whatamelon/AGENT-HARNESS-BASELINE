#!/usr/bin/env bash
# env-sync.sh
# 현재 디렉터리 (또는 인자로 받은 dir)의 .env.template를 1Password에서 채워 .env 생성.
# 사용:
#   env-sync                  # 현재 디렉터리
#   env-sync <project-dir>    # 특정 디렉터리
#   env-sync --dry-run        # 결과 미리보기만 (디스크 안 씀)

set -euo pipefail

readonly G='\033[0;32m'; readonly Y='\033[1;33m'; readonly R='\033[0;31m'; readonly B='\033[1;34m'; readonly N='\033[0m'

DRY=0
DIR="$PWD"
for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY=1 ;;
    -h|--help) echo "사용: env-sync [project-dir] [--dry-run]"; exit 0 ;;
    *) DIR="$arg" ;;
  esac
done

cd "$DIR" || { echo "❌ $DIR 없음"; exit 1; }

[[ -f ".env.template" ]] || { echo "❌ $DIR/.env.template 없음 — project-init 먼저 실행"; exit 1; }

command -v op >/dev/null || { echo "❌ 1Password CLI 미설치"; exit 1; }
op vault list >/dev/null 2>&1 || { echo "❌ op signin 안 됨"; exit 1; }

echo -e "${B}▶${N} ${DIR}/.env 재주입"

if [[ $DRY -eq 1 ]]; then
  echo -e "${Y}--- DRY RUN (.env 변경 없음) ---${N}"
  op inject --force -i .env.template
  exit 0
fi

# 백업
[[ -f ".env" ]] && cp .env ".env.bak.$(date +%Y%m%d-%H%M%S)"

if op inject --force -i .env.template -o .env 2>/dev/null; then
  chmod 600 .env
  KEYS=$(grep -cE '^[A-Z_][A-Z0-9_]*=' .env || echo 0)
  echo -e "  ${G}✓${N} .env 갱신 완료 ($KEYS keys)"
else
  echo -e "  ${R}✗${N} 주입 실패 — 1Password 항목 누락 확인"
  echo -e "  필요한 op 참조 목록:"
  grep -oE '\{\{ op://[^}]+ \}\}' .env.template | sort -u
  exit 1
fi
