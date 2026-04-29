#!/usr/bin/env bash
# bootstrap-new-mac.sh
# 새 맥북 한 방 셋업. idempotent (재실행 안전).
#
# 원격 실행 (네트워크 OK):
#   curl -fsSL https://raw.githubusercontent.com/whatamelon/claude-sync/main/bootstrap/bootstrap-new-mac.sh | bash
# 또는 SSOT 클론 후:
#   ~/.config/claude-sync/bootstrap/bootstrap-new-mac.sh

set -euo pipefail

readonly SSOT_DIR="$HOME/.config/claude-sync"
readonly REPO_URL="https://github.com/whatamelon/claude-sync.git"

# 색상
readonly G='\033[0;32m'   # green
readonly Y='\033[1;33m'   # yellow
readonly R='\033[0;31m'   # red
readonly B='\033[1;34m'   # blue
readonly N='\033[0m'      # reset

step() {
  echo -e "\n${B}▶${N} $*"
  # notify-step hook — silent fail, background
  local _label="$1"
  local _step_num
  _step_num=$(echo "$_label" | grep -oE '^[0-9]+' | head -1)
  local _step_title="${_label#*. }"
  if [[ -n "$_step_num" ]] && [[ -x "${SSOT_DIR}/bin/notify-step.sh" ]]; then
    bash "${SSOT_DIR}/bin/notify-step.sh" update "$_step_num" "15" "🔄" "$_step_title" 2>/dev/null &
    disown $! 2>/dev/null || true
  fi
}
info() { echo -e "  ${G}✓${N} $*"; }
warn() { echo -e "  ${Y}⚠${N} $*"; }
err()  { echo -e "  ${R}✗${N} $*"; }
pause() { echo -e "\n${Y}⏸  ENTER 누르면 계속${N}"; read -r; }

# ─── bootstrap 시작 알림 ──────────────────────────────────────
_bootstrap_start_ts=$(date +%s)
if [[ -x "${SSOT_DIR}/bin/notify-step.sh" ]]; then
  bash "${SSOT_DIR}/bin/notify-step.sh" start "15" 2>/dev/null &
  disown $! 2>/dev/null || true
fi

# ─── 0. 사전 점검 ─────────────────────────────────────────────
step "0. 사전 점검"
[[ "$(uname)" == "Darwin" ]] || { err "macOS 전용"; exit 1; }
info "macOS $(sw_vers -productVersion)"
info "사용자: $USER, 호스트: $(hostname -s)"

# ─── 1. Xcode CLT ─────────────────────────────────────────────
step "1. Xcode Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then
  info "이미 설치됨 ($(xcode-select -p))"
else
  warn "설치 시작 — 다이얼로그 나오면 'Install' 클릭하고 완료 후 ENTER"
  xcode-select --install || true
  pause
fi

# ─── 2. Rosetta (Apple Silicon 한정) ──────────────────────────
step "2. Rosetta"
if [[ "$(uname -m)" == "arm64" ]]; then
  if /usr/bin/pgrep -q oahd; then
    info "Rosetta 이미 설치됨"
  else
    warn "Rosetta 설치 (라이선스 자동 동의)"
    sudo softwareupdate --install-rosetta --agree-to-license || warn "Rosetta 설치 실패 — 무시 (대부분 필요 없음)"
  fi
else
  info "Intel Mac — 스킵"
fi

# ─── 3. Homebrew ──────────────────────────────────────────────
step "3. Homebrew"
if command -v brew >/dev/null 2>&1; then
  info "이미 설치됨 ($(brew --version | head -1))"
else
  warn "설치 중 — 비밀번호 요구할 수 있음"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # PATH 즉시 적용
  if [[ -d "/opt/homebrew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  info "설치 완료"
fi

# ─── 4. SSOT repo clone ───────────────────────────────────────
step "4. claude-sync repo"
mkdir -p "$HOME/.config"
if [[ -d "$SSOT_DIR/.git" ]]; then
  info "이미 clone됨 — git pull"
  (cd "$SSOT_DIR" && git pull --rebase --autostash --quiet) || warn "pull 실패 (네트워크?)"
else
  warn "clone 중..."
  git clone --quiet "$REPO_URL" "$SSOT_DIR"
  info "clone 완료"
fi

# ─── 5. Brewfile 일괄 설치 ────────────────────────────────────
step "5. Brewfile 일괄 설치 (시간 좀 걸림)"
if [[ -f "$SSOT_DIR/bootstrap/Brewfile" ]]; then
  brew bundle --file="$SSOT_DIR/bootstrap/Brewfile" --no-lock 2>&1 | tail -10 || warn "일부 패키지 설치 실패 (무시 가능)"
  info "Brewfile 적용 완료"
else
  warn "Brewfile 없음 — 스킵"
fi

# ─── 6. 1Password CLI ─────────────────────────────────────────
step "6. 1Password CLI"
if command -v op >/dev/null 2>&1; then
  info "이미 설치됨 ($(op --version))"
else
  brew install --cask 1password-cli
  info "설치 완료"
fi

# ─── 7. 1Password 인증 (사람 액션) ───────────────────────────
step "7. 1Password 인증 (★ 사람 액션 필요)"
if [[ -x "${SSOT_DIR}/bin/notify-step.sh" ]]; then
  bash "${SSOT_DIR}/bin/notify-step.sh" human-action "1Password CLI" "데스크톱 앱 → Settings → Developer → CLI integration ON → 새 터미널에서 op signin" 2>/dev/null &
  disown $! 2>/dev/null || true
fi
if op vault list >/dev/null 2>&1; then
  info "이미 인증됨"
else
  cat <<EOF
  ${Y}다음 두 단계를 완료한 뒤 ENTER:${N}
    1) 1Password 데스크톱 앱 → Settings → Developer → "Integrate with 1Password CLI" 토글 ON
    2) 다음 명령으로 CLI 인증: ${B}op signin${N}
       (브라우저로 인증 코드 받음. 또는 마스터 비밀번호 입력)
EOF
  pause
  if op vault list >/dev/null 2>&1; then
    info "인증 성공"
  else
    err "여전히 미인증 — 부트스트랩 계속하지만 시크릿 마이그레이션은 스킵됨"
  fi
fi

# ─── 8. install.sh 실행 (symlink + 셸 + git config) ──────────
step "8. claude-sync install.sh"
"$SSOT_DIR/bin/install.sh"

# ─── 9. 시크릿 자동 주입 (1Password에 항목이 있을 때만) ──────
step "9. 시크릿 자동 주입"
if op vault list >/dev/null 2>&1; then
  TPL="$HOME/.claude/settings.local.tpl.json"
  if [[ -f "$TPL" ]]; then
    op inject --force -i "$TPL" -o "$HOME/.claude/settings.local.json" 2>&1 \
      && info "settings.local.json 주입됨" \
      || warn "주입 실패 — 1Password에 vault 항목이 없을 수 있음"
    "$SSOT_DIR/bin/install.sh" >/dev/null
    info "settings.json 재머지 완료"
  else
    warn "$TPL 없음 — 첫 머신이면 settings.local.example.json 참고해서 직접 작성"
  fi
else
  warn "1Password 미인증 — 시크릿 주입 스킵"
fi

# ─── 10. 글로벌 npm 패키지 ────────────────────────────────────
step "10. npm globals"
if command -v npm >/dev/null 2>&1; then
  if [[ -f "$SSOT_DIR/bootstrap/npm-globals-names.txt" ]]; then
    while IFS= read -r pkg; do
      [[ -z "$pkg" ]] && continue
      if npm list -g --depth=0 "$pkg" >/dev/null 2>&1; then
        info "$pkg (이미 설치)"
      else
        npm install -g --silent "$pkg" 2>&1 | tail -1
        info "$pkg 설치"
      fi
    done < "$SSOT_DIR/bootstrap/npm-globals-names.txt"
  fi
fi

# ─── 11. Bun ──────────────────────────────────────────────────
step "11. Bun"
if command -v bun >/dev/null 2>&1; then
  info "이미 설치됨 ($(bun --version))"
else
  curl -fsSL https://bun.sh/install | bash 2>&1 | tail -3
fi

# ─── 12. launchd 자동 sync 등록 ───────────────────────────────
step "12. launchd 자동 sync (30분 주기)"
PLIST_SRC="$SSOT_DIR/launchd/com.denny.claude-sync.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.denny.claude-sync.plist"
mkdir -p "$HOME/Library/LaunchAgents"
ln -sfn "$PLIST_SRC" "$PLIST_DST"
launchctl unload "$PLIST_DST" 2>/dev/null || true
launchctl load "$PLIST_DST"
launchctl list | grep -q claude-sync && info "launchd 등록됨" || warn "launchd 등록 실패"

# ─── 13. 에디터 확장 (VS Code / Cursor) ──────────────────────
step "13. VS Code / Cursor 확장"
if command -v code >/dev/null 2>&1 && [[ -f "$SSOT_DIR/editors/vscode-extensions.txt" ]]; then
  while IFS= read -r ext; do
    [[ -z "$ext" ]] && continue
    code --install-extension "$ext" --force >/dev/null 2>&1 && info "code: $ext"
  done < "$SSOT_DIR/editors/vscode-extensions.txt"
else
  warn "code CLI 없음 — VS Code 설치 후 'Shell Command: Install code command in PATH'"
fi
if command -v cursor >/dev/null 2>&1 && [[ -f "$SSOT_DIR/editors/cursor-extensions.txt" ]]; then
  while IFS= read -r ext; do
    [[ -z "$ext" ]] && continue
    cursor --install-extension "$ext" --force >/dev/null 2>&1 && info "cursor: $ext"
  done < "$SSOT_DIR/editors/cursor-extensions.txt"
else
  warn "cursor CLI 없음 — Cursor 설치 후 'Shell Command: Install cursor command in PATH'"
fi

# ─── 13b. 공유 자산 동기화 (스킬 풀 + 글로벌 AGENTS.md) ───────
step "13b. 공유 자산 동기화 (CC ↔ Codex 스킬 + 글로벌 AGENTS.md)"
"$SSOT_DIR/bootstrap/install-shared-skills.sh" || true
"$SSOT_DIR/bootstrap/install-codex-skills.sh" || true
"$SSOT_DIR/bin/rebuild-agents-md.sh" --quiet || true

# ─── 14. 검증 ─────────────────────────────────────────────────
step "14. 검증 (cs-doctor)"
"$SSOT_DIR/bin/doctor.sh" || true

# ─── 15. 최종 안내 (사람 액션 체크리스트) ────────────────────
step "15. ★ 남은 사람 액션 (CLI 로그인)"
if [[ -x "${SSOT_DIR}/bin/notify-step.sh" ]]; then
  bash "${SSOT_DIR}/bin/notify-step.sh" human-action "CLI OAuth 인증" "gh / gcloud / supabase / vercel / docker / firebase / claude — 각각 별도 터미널에서 로그인 필요" 2>/dev/null &
  disown $! 2>/dev/null || true
fi
cat <<EOF

  ${Y}자동화 불가능한 OAuth 로그인들 — 한 번씩 실행:${N}

  [필수]
  ${B}gh auth login${N}                        # GitHub
  ${B}op signin${N}                            # 1Password (위에서 안 됐다면)

  [있는 도구만]
  ${B}gcloud init${N}                          # Google Cloud
  ${B}gcloud auth application-default login${N}
  ${B}vercel login${N}                         # Vercel
  ${B}supabase login${N}                       # Supabase
  ${B}docker login${N}                         # Docker Hub
  ${B}firebase login${N}                       # Firebase
  ${B}wrangler login${N}                       # Cloudflare Workers
  ${B}claude${N}                               # Claude Code 첫 인증

  [선택]
  Android Studio 첫 실행 (JDK 활성화)
  Xcode 첫 실행 + 라이선스 동의

  ${Y}참고:${N} ${B}cli-login-checklist.md${N} 에 상세 가이드

EOF

# ─── bootstrap 완료 알림 ──────────────────────────────────────
if [[ -x "${SSOT_DIR}/bin/notify-step.sh" ]]; then
  _bootstrap_elapsed=$(( $(date +%s) - _bootstrap_start_ts ))
  bash "${SSOT_DIR}/bin/notify-step.sh" done "15" "${_bootstrap_elapsed}s" 2>/dev/null &
  disown $! 2>/dev/null || true
fi

step "✅ 부트스트랩 완료"
cat <<EOF

다음:
  1. ${B}exec zsh${N} (또는 새 터미널) 로 alias 활성화
  2. 위 [필수] 로그인 진행
  3. ${B}cs-doctor${N} 로 다시 검증
  4. 첫 프로젝트 등록: ${B}cd <project> && project-init${N}

EOF
