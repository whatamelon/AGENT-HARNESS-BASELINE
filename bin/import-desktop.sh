#!/usr/bin/env zsh
# import-desktop.sh — SSOT의 GUI 앱 설정을 현재 머신에 복사 (새 머신에서 실행)
# 기존 파일은 .bak 으로 백업 후 덮어씀.
# 사용:
#   import-desktop          # 인터랙티브 (앱별 yes/no)
#   import-desktop --all    # 전체 자동 import
#   import-desktop --dry    # 어떤 파일이 바뀌는지만 표시

set -uo pipefail

readonly SSOT="$HOME/.config/claude-sync"
readonly SRC="$SSOT/desktop"
source "$SSOT/shell/ui-lib.sh"

[[ -d "$SRC" ]] || { ui_err "$SRC 없음 — git pull 먼저"; exit 1; }

MODE="interactive"
case "${1:-}" in
  --all|-y) MODE="all" ;;
  --dry|-n) MODE="dry" ;;
  -h|--help)
    cat <<EOF
import-desktop [모드]
  (없음)   인터랙티브 — 앱별로 yes/no
  --all    전체 자동 import (기존 파일 .bak으로 백업)
  --dry    드라이런 (어떤 파일이 바뀌는지만 표시)
EOF
    exit 0 ;;
esac

ui_main_banner
echo -e "  ${UI_BOLD}${UI_CYAN}📥 데스크톱 설정 IMPORT (SSOT → 현재 머신)${UI_R}\n"

# 백업+복사 헬퍼
__copy_with_backup() {
  local src="$1" dst="$2"
  if [[ "$MODE" == "dry" ]]; then
    if [[ -f "$dst" ]]; then
      ui_arrow "$dst ${UI_DIM}(덮어쓰기 예정)${UI_R}"
    else
      ui_arrow "$dst ${UI_DIM}(신규)${UI_R}"
    fi
    return
  fi
  mkdir -p "$(dirname "$dst")"
  if [[ -f "$dst" ]] && ! cmp -s "$src" "$dst"; then
    cp "$dst" "$dst.bak.$(date +%Y%m%d-%H%M%S)"
  fi
  cp "$src" "$dst"
  ui_ok "$(basename "$dst")"
}

# rsync 디렉토리 헬퍼 (백업 없이 단순 sync — snippets 등)
__sync_dir() {
  local src="$1" dst="$2"
  if [[ "$MODE" == "dry" ]]; then
    ui_arrow "$dst/ ${UI_DIM}(rsync 동기화 예정)${UI_R}"
    return
  fi
  mkdir -p "$dst"
  rsync -a "$src/" "$dst/" 2>/dev/null
  ui_ok "$(basename "$dst")/"
}

__ask_or_skip() {
  local label="$1"
  [[ "$MODE" == "all" || "$MODE" == "dry" ]] && return 0
  ui_ask_yn "    $label import?" "y"
}

# ─── iTerm2 ────────────────────────────────────────────
if [[ -d "$SRC/iterm2" ]]; then
  ui_section "iTerm2"
  if __ask_or_skip "iTerm2"; then
    [[ -f "$SRC/iterm2/com.googlecode.iterm2.plist" ]] && \
      __copy_with_backup "$SRC/iterm2/com.googlecode.iterm2.plist" \
                         "$HOME/Library/Preferences/com.googlecode.iterm2.plist"
    [[ -d "$SRC/iterm2/DynamicProfiles" ]] && \
      __sync_dir "$SRC/iterm2/DynamicProfiles" \
                 "$HOME/Library/Application Support/iTerm2/DynamicProfiles"
    if [[ "$MODE" != "dry" ]]; then
      defaults read com.googlecode.iterm2 >/dev/null 2>&1 || true
      ui_info "${UI_DIM}iTerm 재시작 필요${UI_R}"
    fi
  else
    ui_skip "iTerm2"
  fi
fi

# ─── VS Code ────────────────────────────────────────────
if [[ -d "$SRC/vscode" ]]; then
  ui_section "VS Code"
  if __ask_or_skip "VS Code"; then
    local vsc_dst="$HOME/Library/Application Support/Code/User"
    for f in settings.json keybindings.json; do
      [[ -f "$SRC/vscode/$f" ]] && __copy_with_backup "$SRC/vscode/$f" "$vsc_dst/$f"
    done
    [[ -d "$SRC/vscode/snippets" ]] && __sync_dir "$SRC/vscode/snippets" "$vsc_dst/snippets"
  else
    ui_skip "VS Code"
  fi
fi

# ─── Cursor ────────────────────────────────────────────
if [[ -d "$SRC/cursor" ]]; then
  ui_section "Cursor"
  if __ask_or_skip "Cursor"; then
    local cur_dst="$HOME/Library/Application Support/Cursor/User"
    for f in settings.json keybindings.json; do
      [[ -f "$SRC/cursor/$f" ]] && __copy_with_backup "$SRC/cursor/$f" "$cur_dst/$f"
    done
    [[ -d "$SRC/cursor/snippets" ]] && __sync_dir "$SRC/cursor/snippets" "$cur_dst/snippets"
  else
    ui_skip "Cursor"
  fi
fi

# ─── Claude Desktop (op inject로 시크릿 주입) ──────────
if [[ -d "$SRC/claude-desktop" ]]; then
  ui_section "Claude Desktop"
  if __ask_or_skip "Claude Desktop"; then
    local tpl="$SRC/claude-desktop/claude_desktop_config.tpl.json"
    local dst="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    if [[ ! -f "$tpl" ]]; then
      ui_warn "claude_desktop_config.tpl.json 없음 — 스킵"
    elif [[ "$MODE" == "dry" ]]; then
      ui_arrow "$dst ${UI_DIM}(op inject 후 덮어쓰기 예정)${UI_R}"
    elif ! command -v op >/dev/null 2>&1; then
      ui_warn "1Password CLI(op) 없음 — 스킵 (3단계 먼저)"
    elif ! op vault list >/dev/null 2>&1; then
      ui_warn "1Password 미인증 — 'op signin' 후 재시도"
    else
      mkdir -p "$(dirname "$dst")"
      [[ -f "$dst" ]] && cp "$dst" "$dst.bak.$(date +%Y%m%d-%H%M%S)"
      if op inject --force -i "$tpl" -o "$dst" 2>/dev/null; then
        chmod 600 "$dst"
        ui_ok "claude_desktop_config.json (op inject 완료)"
      else
        ui_err "op inject 실패 — Employee/Upstash-MCP 항목 확인"
      fi
    fi
  else
    ui_skip "Claude Desktop"
  fi
fi

echo
if [[ "$MODE" == "dry" ]]; then
  ui_info "드라이런 — 실제 변경 없음"
else
  ui_celebrate "IMPORT 완료"
  ui_info "${UI_DIM}iTerm/VS Code/Cursor 재시작하면 설정 적용됨${UI_R}"
fi
