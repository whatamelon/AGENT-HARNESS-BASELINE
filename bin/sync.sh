#!/usr/bin/env bash
# sync.sh — launchd 가 30분마다 호출. pull → 변경 있으면 자동 commit/push.
set -uo pipefail

SSOT="$HOME/.config/claude-sync"
cd "$SSOT" || exit 1

# 원격 없으면 스킵
git remote get-url origin >/dev/null 2>&1 || exit 0

# Pull
git pull --rebase --autostash --quiet 2>&1 || exit 1

# Push 할 변경 있는지
if [[ -n "$(git status --porcelain)" ]]; then
  git add .
  git commit -m "auto: $(hostname -s) $(date +%FT%T%z)" --quiet
  git push --quiet 2>&1
fi
