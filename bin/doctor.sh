#!/usr/bin/env bash
# doctor.sh — symlink/git/secret 상태 점검
set -uo pipefail

SSOT="$HOME/.config/claude-sync"
errors=0

check_link() {
  local link="$1" target="$2"
  if [[ ! -L "$link" ]]; then
    echo "❌ NOT a symlink: $link"; ((errors++))
  elif [[ "$(readlink "$link")" != "$target" ]]; then
    echo "❌ wrong target: $link → $(readlink "$link")"
    echo "   expected: $target"; ((errors++))
  else
    echo "✓ $link"
  fi
}

echo "── Symlink 검증 ──"
for d in skills agents commands rules hooks hud; do
  check_link "$HOME/.claude/$d" "$SSOT/claude/$d"
done
check_link "$HOME/.claude/notify.sh" "$SSOT/claude/notify.sh"
check_link "$HOME/.claude/CLAUDE.md" "$SSOT/claude/CLAUDE.md"
check_link "$HOME/.claude/.mcp.json" "$SSOT/claude/mcp.shared.json"
check_link "$HOME/.config/projects" "$SSOT/config/projects"

echo ""
echo "── settings.json 상태 ──"
if [[ -f "$HOME/.claude/settings.local.json" ]]; then
  echo "✓ settings.local.json 존재 ($(stat -f%Sp $HOME/.claude/settings.local.json))"
  if jq empty "$HOME/.claude/settings.local.json" 2>/dev/null; then
    echo "✓ JSON valid"
    keys=$(jq -r '.env | keys | join(", ")' "$HOME/.claude/settings.local.json" 2>/dev/null)
    echo "  env keys: $keys"
  else
    echo "❌ JSON invalid"; ((errors++))
  fi
else
  echo "⚠ settings.local.json 없음 — install.sh 다시 돌리거나 직접 만들기"
fi

echo ""
echo "── 셸 source 라인 ──"
grep -q "claude-sync/shell/zshrc.shared" "$HOME/.zshrc" 2>/dev/null \
  && echo "✓ ~/.zshrc 에 source 있음" \
  || { echo "❌ ~/.zshrc 에 source 없음"; ((errors++)); }
grep -q "claude-sync/shell/zprofile.shared" "$HOME/.zprofile" 2>/dev/null \
  && echo "✓ ~/.zprofile 에 source 있음" \
  || { echo "❌ ~/.zprofile 에 source 없음"; ((errors++)); }

echo ""
echo "── 1Password CLI ──"
if command -v op >/dev/null; then
  echo "✓ op 설치 ($(op --version))"
  if op vault list >/dev/null 2>&1; then
    echo "✓ op signin 됨"
  else
    echo "⚠ op signin 안 됨 — 'op signin' 실행 필요"
  fi
else
  echo "❌ op 미설치"; ((errors++))
fi

echo ""
echo "── Git 상태 ──"
cd "$SSOT" 2>/dev/null && {
  branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "?")
  echo "✓ branch: $branch"
  remote=$(git remote get-url origin 2>/dev/null || echo "(원격 없음)")
  echo "  remote: $remote"
  if [[ "$remote" != "(원격 없음)" ]]; then
    counts=$(git rev-list --left-right --count "origin/$branch...HEAD" 2>/dev/null || echo "? ?")
    behind=$(echo "$counts" | awk '{print $1}')
    ahead=$(echo "$counts" | awk '{print $2}')
    echo "  behind: $behind, ahead: $ahead"
  fi
  modified=$(git status --short | wc -l | tr -d ' ')
  echo "  uncommitted: $modified files"
} || { echo "❌ SSOT git 접근 실패"; ((errors++)); }

echo ""
echo "── launchd 자동 sync ──"
if launchctl list | grep -q "com.denny.claude-sync"; then
  echo "✓ launchd 등록됨 (com.denny.claude-sync)"
else
  echo "⚠ launchd 미등록 — bin/install-launchd.sh 실행"
fi

echo ""
[[ $errors -eq 0 ]] && echo "✅ All good ($errors errors)" || echo "❌ $errors errors"
exit $errors
