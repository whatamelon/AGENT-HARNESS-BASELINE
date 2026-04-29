#!/usr/bin/env zsh
# export-desktop.sh — 현재 머신의 GUI 앱 설정을 SSOT로 복사 (개인맥에서 실행)
# 멱등. 항상 SSOT 버전 덮어씀.

set -uo pipefail

readonly SSOT="$HOME/.config/claude-sync"
readonly DEST="$SSOT/desktop"
source "$SSOT/shell/ui-lib.sh"

ui_main_banner
echo -e "  ${UI_BOLD}${UI_CYAN}📤 데스크톱 설정 EXPORT (현재 머신 → SSOT)${UI_R}\n"

# ─── iTerm2 ────────────────────────────────────────────
ui_section "iTerm2"
if [[ -f "$HOME/Library/Preferences/com.googlecode.iterm2.plist" ]]; then
  cp "$HOME/Library/Preferences/com.googlecode.iterm2.plist" \
     "$DEST/iterm2/com.googlecode.iterm2.plist"
  ui_ok "plist 복사"

  if [[ -d "$HOME/Library/Application Support/iTerm2/DynamicProfiles" ]]; then
    rsync -a --delete \
      "$HOME/Library/Application Support/iTerm2/DynamicProfiles/" \
      "$DEST/iterm2/DynamicProfiles/" 2>/dev/null
    ui_ok "DynamicProfiles 동기화"
  fi
else
  ui_skip "iTerm2 plist 없음"
fi

# ─── VS Code ────────────────────────────────────────────
ui_section "VS Code"
local vsc_src="$HOME/Library/Application Support/Code/User"
if [[ -d "$vsc_src" ]]; then
  for f in settings.json keybindings.json; do
    if [[ -f "$vsc_src/$f" ]]; then
      cp "$vsc_src/$f" "$DEST/vscode/$f"
      ui_ok "$f"
    fi
  done
  if [[ -d "$vsc_src/snippets" ]]; then
    rsync -a --delete "$vsc_src/snippets/" "$DEST/vscode/snippets/" 2>/dev/null
    ui_ok "snippets 동기화"
  fi
else
  ui_skip "VS Code 설정 없음"
fi

# ─── Cursor ────────────────────────────────────────────
ui_section "Cursor"
local cur_src="$HOME/Library/Application Support/Cursor/User"
if [[ -d "$cur_src" ]]; then
  for f in settings.json keybindings.json; do
    if [[ -f "$cur_src/$f" ]]; then
      cp "$cur_src/$f" "$DEST/cursor/$f"
      ui_ok "$f"
    fi
  done
  if [[ -d "$cur_src/snippets" ]]; then
    rsync -a --delete "$cur_src/snippets/" "$DEST/cursor/snippets/" 2>/dev/null
    ui_ok "snippets 동기화"
  fi
else
  ui_skip "Cursor 설정 없음"
fi

# ─── Claude Desktop (MCP 등) ───────────────────────────
ui_section "Claude Desktop"
local cd_src="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
if [[ -f "$cd_src" ]]; then
  cp "$cd_src" "$DEST/claude-desktop/claude_desktop_config.json"
  ui_ok "claude_desktop_config.json"
else
  ui_skip "Claude Desktop config 없음"
fi

echo
ui_celebrate "EXPORT 완료 — $DEST"
echo
ui_info "${UI_DIM}다음: cd $SSOT && git add desktop && git commit && git push${UI_R}"
