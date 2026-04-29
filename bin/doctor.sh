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
echo "── CC ↔ Codex 통합 ──"

# ~/AGENTS.md (Codex 글로벌 컨벤션, 자동 생성)
if [[ -f "$HOME/AGENTS.md" ]]; then
  if head -1 "$HOME/AGENTS.md" | grep -q "AUTO-GENERATED"; then
    echo "✓ ~/AGENTS.md 빌드됨 ($(wc -c < "$HOME/AGENTS.md" | tr -d ' ') bytes)"
  else
    echo "⚠ ~/AGENTS.md 에 AUTO-GENERATED 마커 없음 — 직접 편집된 듯. 'rebuild-agents-md.sh --force' 권장"
  fi
else
  echo "⚠ ~/AGENTS.md 없음 — 'bin/rebuild-agents-md.sh' 실행"
fi

# 외부 공유 스킬 풀 (CC + Codex 양쪽 의존)
if [[ -d "$HOME/.agents/skills" ]]; then
  shared_count=$(ls "$HOME/.agents/skills" 2>/dev/null | wc -l | tr -d ' ')
  echo "✓ ~/.agents/skills ($shared_count 개)"
else
  echo "❌ ~/.agents/skills 없음 — 'bootstrap/install-shared-skills.sh' 실행"; ((errors++))
fi

# Codex 스킬 통합 (Codex 설치된 경우만)
if [[ -d "$HOME/.codex/skills" ]]; then
  codex_count=$(ls "$HOME/.codex/skills" 2>/dev/null | wc -l | tr -d ' ')
  echo "✓ ~/.codex/skills ($codex_count 개)"
  if [[ -L "$HOME/.codex/skills/react-patterns" ]]; then
    echo "✓ CC 전용 스킬 노출됨 (react-patterns 등 7개)"
  else
    echo "⚠ CC 전용 스킬 미노출 — 'bootstrap/install-codex-skills.sh' 실행"
  fi
fi

# 빌더/인스톨러 실행 권한
for s in bin/rebuild-agents-md.sh bootstrap/install-shared-skills.sh bootstrap/install-codex-skills.sh; do
  if [[ -x "$SSOT/$s" ]]; then
    echo "✓ $s"
  else
    echo "❌ $s 실행 권한/존재 X"; ((errors++))
  fi
done

# PostToolUse hook trigger 등록 여부
if jq -e '.hooks.PostToolUse[]?.hooks[]? | select(.command | contains("rebuild-agents-md"))' "$HOME/.claude/settings.json" >/dev/null 2>&1; then
  echo "✓ PostToolUse hook 에 rebuild-agents-md trigger 등록"
else
  echo "⚠ PostToolUse hook trigger 미등록 — rules/MEMORY 수정해도 자동 빌드 안 됨"
fi

echo ""
[[ $errors -eq 0 ]] && echo "✅ All good ($errors errors)" || echo "❌ $errors errors"
exit $errors
