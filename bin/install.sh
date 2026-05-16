#!/usr/bin/env bash
# install.sh — 새 머신에서 한 번만 실행. symlink + 셸 + git config 모두 잡아줌.
set -euo pipefail

SSOT="$HOME/.config/agent-harness-baseline"
[[ -d "$SSOT" ]] || { echo "❌ SSOT 없음: $SSOT"; exit 1; }

echo "▶ Claude 디렉터리 symlink"
mkdir -p "$HOME/.claude"
for d in skills agents commands rules hooks hud; do
  if [[ -e "$HOME/.claude/$d" && ! -L "$HOME/.claude/$d" ]]; then
    mv "$HOME/.claude/$d" "$HOME/.claude/$d.bak.$(date +%s)"
  fi
  ln -sfn "$SSOT/claude/$d" "$HOME/.claude/$d"
  echo "  ✓ ~/.claude/$d"
done
for f in notify.sh CLAUDE.md; do
  if [[ -e "$HOME/.claude/$f" && ! -L "$HOME/.claude/$f" ]]; then
    mv "$HOME/.claude/$f" "$HOME/.claude/$f.bak.$(date +%s)"
  fi
  ln -sfn "$SSOT/claude/$f" "$HOME/.claude/$f"
  echo "  ✓ ~/.claude/$f"
done

echo "▶ 공유 디자인 컨텍스트 symlink"
if [[ -x "$SSOT/bin/link-design.sh" ]]; then
  "$SSOT/bin/link-design.sh"
fi

echo "▶ MCP shared symlink"
if [[ -e "$HOME/.claude/.mcp.json" && ! -L "$HOME/.claude/.mcp.json" ]]; then
  mv "$HOME/.claude/.mcp.json" "$HOME/.claude/.mcp.json.bak.$(date +%s)"
fi
ln -sfn "$SSOT/claude/mcp.shared.json" "$HOME/.claude/.mcp.json"
echo "  ✓ ~/.claude/.mcp.json"

echo "▶ settings.json 머지 (shared + local)"
if [[ ! -f "$HOME/.claude/settings.local.json" ]]; then
  echo "  ⚠ settings.local.json 없음 — example로 시작"
  cp "$SSOT/claude/settings.local.example.json" "$HOME/.claude/settings.local.json"
  chmod 600 "$HOME/.claude/settings.local.json"
  echo "  ⚠ ~/.claude/settings.local.json 직접 편집해서 시크릿 채우세요 (또는 op read 사용)"
fi
jq -s '.[0] * .[1]' \
  "$SSOT/claude/settings.shared.json" \
  "$HOME/.claude/settings.local.json" \
  > "$HOME/.claude/settings.json"
echo "  ✓ ~/.claude/settings.json"

echo "▶ 글로벌 프로젝트 매핑 symlink"
mkdir -p "$HOME/.config"
if [[ -e "$HOME/.config/projects" && ! -L "$HOME/.config/projects" ]]; then
  mv "$HOME/.config/projects" "$HOME/.config/projects.bak.$(date +%s)"
fi
ln -sfn "$SSOT/config/projects" "$HOME/.config/projects"
echo "  ✓ ~/.config/projects"

echo "▶ 셸 설정"
SHARED_LINE="source $SSOT/shell/zshrc.shared"
if ! grep -qF "$SHARED_LINE" "$HOME/.zshrc" 2>/dev/null; then
  echo "" >> "$HOME/.zshrc"
  echo "# agent-harness-baseline" >> "$HOME/.zshrc"
  echo "$SHARED_LINE" >> "$HOME/.zshrc"
  echo "  ✓ ~/.zshrc 에 source 라인 추가"
else
  echo "  • ~/.zshrc 에 이미 source 라인 있음"
fi

ZPROF_LINE="source $SSOT/shell/zprofile.shared"
if ! grep -qF "$ZPROF_LINE" "$HOME/.zprofile" 2>/dev/null; then
  echo "" >> "$HOME/.zprofile"
  echo "# agent-harness-baseline" >> "$HOME/.zprofile"
  echo "$ZPROF_LINE" >> "$HOME/.zprofile"
  echo "  ✓ ~/.zprofile 에 source 라인 추가"
else
  echo "  • ~/.zprofile 에 이미 source 라인 있음"
fi

echo "▶ ~/.zshrc.local 머신별 설정 (없으면 example로 시작)"
if [[ ! -f "$HOME/.zshrc.local" ]]; then
  if [[ -f "$SSOT/shell/zshrc.local.example" ]]; then
    cp "$SSOT/shell/zshrc.local.example" "$HOME/.zshrc.local"
    echo "  ✓ ~/.zshrc.local 생성 (prompt, zoxide/atuin/fzf/eza alias)"
  fi
else
  echo "  • ~/.zshrc.local 이미 존재"
fi

echo "▶ git config include"
git config --global include.path "$SSOT/git/gitconfig.shared" 2>/dev/null || true
echo "  ✓ git include 등록"

echo ""
echo "✅ install.sh 완료. exec zsh 또는 새 터미널 열기."
echo ""
echo "다음 단계:"
echo "  1. ~/.zshrc.local 에 머신별 시크릿/이메일 설정"
echo "  2. ~/.claude/settings.local.json 시크릿 채우기 (또는 op inject 사용)"
echo "  3. ahb-doctor 로 검증"
