#!/usr/bin/env zsh
# mac-setup.sh — 개발환경 꾸쮹
# Mac Setup Wizard — 13단계 풀 셋업.
# 사용:
#   mac-setup           # 인터랙티브 (모드 선택)
#   mac-setup auto      # 처음부터 끝까지 자동
#   mac-setup verify    # 검증만
#   mac-setup --step N  # 특정 단계만

set -uo pipefail

readonly SSOT="$HOME/.config/claude-sync"
readonly STATE_FILE="$SSOT/state/wizard-state.json"
readonly TOTAL_STEPS=13

source "$SSOT/shell/ui-lib.sh"

mkdir -p "$(dirname "$STATE_FILE")"
[[ -f "$STATE_FILE" ]] || echo '{"completed":[],"started_at":""}' > "$STATE_FILE"

# ─── 상태 관리 ────────────────────────────────────────────
__step_done() {
  local n=$1
  local tmp=$(mktemp)
  jq --argjson n "$n" '.completed = (.completed + [$n] | unique)' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
}

__is_done() {
  local n=$1
  jq -e --argjson n "$n" '.completed | index($n)' "$STATE_FILE" >/dev/null 2>&1
}

__reset_state() {
  echo '{"completed":[],"started_at":"'$(date -u +%FT%TZ)'"}' > "$STATE_FILE"
}

# ─── 13단계 함수들 ────────────────────────────────────────
step_01_system_check() {
  ui_step_header 1 $TOTAL_STEPS "시스템 사전 점검"
  ui_ok "macOS $(sw_vers -productVersion)"
  ui_ok "Architecture: $(uname -m)"

  if xcode-select -p >/dev/null 2>&1; then
    ui_ok "Xcode CLT ($(xcode-select -p))"
  else
    ui_warn "Xcode CLT 없음 — 설치 다이얼로그 띄움"
    xcode-select --install 2>/dev/null || true
    ui_pause "다이얼로그에서 Install 클릭하고 완료 후 ENTER"
  fi

  if [[ "$(uname -m)" == "arm64" ]]; then
    if /usr/bin/pgrep -q oahd 2>/dev/null; then
      ui_ok "Rosetta 설치됨"
    else
      ui_doing "Rosetta 설치"
      sudo softwareupdate --install-rosetta --agree-to-license 2>/dev/null || ui_warn "Rosetta 스킵 (선택)"
    fi
  else
    ui_skip "Intel Mac — Rosetta 불필요"
  fi
  __step_done 1
}

step_02_homebrew() {
  ui_step_header 2 $TOTAL_STEPS "Homebrew + Brewfile (CLI/툴)"

  if command -v brew >/dev/null 2>&1; then
    ui_ok "Homebrew $(brew --version | head -1)"
  else
    ui_doing "Homebrew 설치 (비밀번호 요구할 수 있음)"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -d "/opt/homebrew" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    else
      eval "$(/usr/local/bin/brew shellenv)"
    fi
    ui_ok "Homebrew 설치 완료"
  fi

  local brewfile="$SSOT/bootstrap/Brewfile"
  if [[ -f "$brewfile" ]]; then
    local count
    count=$(grep -cE '^(brew|cask|tap)' "$brewfile")
    ui_section "Brewfile ($count 개 항목)"
    if ui_ask_yn "    brew bundle 실행? (5~10분)" "y"; then
      ui_doing "brew bundle 실행 중 (시간 좀 걸림)"
      brew bundle --file="$brewfile" --no-lock 2>&1 | tail -5
      ui_ok "Brewfile 적용 완료"
    else
      ui_skip "Brewfile 스킵"
    fi
  else
    ui_warn "Brewfile 없음 — 스킵"
  fi
  __step_done 2
}

step_03_1password() {
  ui_step_header 3 $TOTAL_STEPS "1Password CLI + 인증"

  if command -v op >/dev/null 2>&1; then
    ui_ok "op $(op --version)"
  else
    ui_doing "1Password CLI 설치"
    brew install --cask 1password-cli >/dev/null
    ui_ok "설치 완료"
  fi

  if op vault list >/dev/null 2>&1; then
    ui_ok "1Password 인증됨 ($(op vault list 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')개 vault)"
  else
    ui_section "${UI_AMBER}사람 액션 필요${UI_R}"
    ui_arrow "1) 1Password 데스크톱 앱 → Settings → Developer → CLI integration ON"
    ui_arrow "2) 새 터미널에서: ${UI_BOLD}${UI_CYAN}op signin${UI_R}"
    ui_pause "완료 후 ENTER"

    if op vault list >/dev/null 2>&1; then
      ui_ok "인증 확인됨"
    else
      ui_warn "여전히 미인증 — 시크릿 주입 단계는 자동 스킵됨"
    fi
  fi
  __step_done 3
}

step_04_claude_sync() {
  ui_step_header 4 $TOTAL_STEPS "claude-sync clone + install.sh"

  if [[ -d "$SSOT/.git" ]]; then
    ui_ok "이미 clone됨 — git pull"
    (cd "$SSOT" && git pull --rebase --autostash --quiet 2>/dev/null) && ui_ok "최신" || ui_warn "pull 실패 (네트워크?)"
  else
    ui_doing "clone 중"
    git clone --quiet https://github.com/whatamelon/claude-sync.git "$SSOT"
    ui_ok "clone 완료"
  fi

  ui_doing "install.sh 실행 (symlink + 셸 wiring)"
  "$SSOT/bin/install.sh" >/dev/null 2>&1
  ui_ok "Claude/셸/git config 통합 완료"
  __step_done 4
}

step_05_codex() {
  ui_step_header 5 $TOTAL_STEPS "공유 자산 통합 (외부 스킬 풀 + Codex + 글로벌 AGENTS.md)"

  # (1) 외부 출처 스킬 157개 재구성 — CC와 Codex 둘 다 의존
  if [[ -f "$SSOT/bootstrap/install-shared-skills.sh" ]]; then
    ui_doing "~/.agents/skills 재구성 (외부 157개)"
    bash "$SSOT/bootstrap/install-shared-skills.sh" 2>&1 | tail -3
    ui_ok "공유 스킬 풀 동기화 완료"
  fi

  # (2) Codex CLI 통합 — CC 전용 7개를 Codex 에 노출
  if command -v codex >/dev/null 2>&1 || [[ -d /Applications/Codex.app ]]; then
    if [[ -f "$SSOT/bootstrap/install-codex-skills.sh" ]]; then
      ui_doing "~/.codex/skills 심링크"
      bash "$SSOT/bootstrap/install-codex-skills.sh" 2>&1 | tail -3
      ui_ok "Codex 스킬 통합 완료"
    else
      ui_skip "install-codex-skills.sh 없음"
    fi
  else
    ui_skip "Codex 미설치 — 스킵 (필요 시 brew install --cask codex)"
  fi

  # (3) 글로벌 AGENTS.md 빌드 — CC ↔ Codex 공유 규칙/메모리
  if [[ -f "$SSOT/bin/rebuild-agents-md.sh" ]]; then
    ui_doing "~/AGENTS.md 빌드"
    bash "$SSOT/bin/rebuild-agents-md.sh" --quiet
    ui_ok "글로벌 컨벤션 동기화 완료"
  fi

  __step_done 5
}

step_06_secrets() {
  ui_step_header 6 $TOTAL_STEPS "시크릿 자동 주입 (1Password → settings.local.json)"

  if ! op vault list >/dev/null 2>&1; then
    ui_warn "1Password 미인증 — 스킵 (3단계 완료 후 재시도)"
    return 0
  fi

  local tpl="$HOME/.claude/settings.local.tpl.json"
  if [[ -f "$tpl" ]]; then
    ui_doing "op inject로 settings.local.json 주입"
    if op inject --force -i "$tpl" -o "$HOME/.claude/settings.local.json" 2>/dev/null; then
      chmod 600 "$HOME/.claude/settings.local.json"
      "$SSOT/bin/install.sh" >/dev/null
      local keys
      keys=$(jq -r '.env | keys | join(", ")' "$HOME/.claude/settings.local.json" 2>/dev/null)
      ui_ok "주입 완료: $keys"
    else
      ui_warn "주입 실패 — 1Password에 vault 항목 누락 가능"
    fi
  else
    ui_warn "$tpl 없음 — secrets-migrate <vault> 로 먼저 1Password에 항목 만들기"
    if ui_ask_yn "    지금 secrets-migrate Employee 실행?" "n"; then
      "$SSOT/bin/migrate-secrets-to-1password.sh" Employee
    fi
  fi
  __step_done 6
}

step_07_npm_bun() {
  ui_step_header 7 $TOTAL_STEPS "npm globals + Bun"

  if command -v npm >/dev/null 2>&1; then
    local list="$SSOT/bootstrap/npm-globals-names.txt"
    if [[ -f "$list" ]]; then
      local pkgs i=0 total
      pkgs=( $(cat "$list") )
      total=${#pkgs[@]}
      for pkg in "${pkgs[@]}"; do
        (( i++ ))
        if npm list -g --depth=0 "$pkg" >/dev/null 2>&1; then
          ui_skip "$pkg ($i/$total)"
        else
          ui_doing "npm i -g $pkg ($i/$total)"
          npm install -g --silent "$pkg" >/dev/null 2>&1 && ui_ok "$pkg" || ui_err "$pkg 실패"
        fi
      done
    fi
  fi

  if command -v bun >/dev/null 2>&1; then
    ui_ok "Bun $(bun --version)"
  else
    ui_doing "Bun 설치"
    curl -fsSL https://bun.sh/install | bash >/dev/null 2>&1
    ui_ok "Bun 설치 완료"
  fi
  __step_done 7
}

step_08_launchd() {
  ui_step_header 8 $TOTAL_STEPS "launchd 자동 sync (30분 주기)"

  local plist_src="$SSOT/launchd/com.denny.claude-sync.plist"
  local plist_dst="$HOME/Library/LaunchAgents/com.denny.claude-sync.plist"

  if launchctl list 2>/dev/null | grep -q claude-sync; then
    ui_ok "launchd 이미 등록됨"
  else
    mkdir -p "$HOME/Library/LaunchAgents"
    ln -sfn "$plist_src" "$plist_dst"
    launchctl load "$plist_dst" 2>/dev/null
    if launchctl list 2>/dev/null | grep -q claude-sync; then
      ui_ok "com.denny.claude-sync 등록 완료 (30분 주기)"
    else
      ui_err "launchd 등록 실패"
    fi
  fi
  __step_done 8
}

step_09_apps() {
  ui_step_header 9 $TOTAL_STEPS "데스크톱 앱 설치"
  ui_info "${UI_DIM}install-apps 호출 (별도 마법사)${UI_R}"
  echo
  "$SSOT/bin/install-apps.sh"
  __step_done 9
}

step_10_editors() {
  ui_step_header 10 $TOTAL_STEPS "VS Code / Cursor 확장"

  local installed=0
  if command -v code >/dev/null 2>&1 && [[ -f "$SSOT/editors/vscode-extensions.txt" ]]; then
    while IFS= read -r ext; do
      [[ -z "$ext" ]] && continue
      if code --list-extensions 2>/dev/null | grep -qFx "$ext"; then
        ui_skip "code: $ext"
      else
        code --install-extension "$ext" --force >/dev/null 2>&1 && { ui_ok "code: $ext"; (( installed++ )); }
      fi
    done < "$SSOT/editors/vscode-extensions.txt"
  else
    ui_warn "VS Code CLI 없음 — 명령 팔레트에서 'Shell Command: Install code command in PATH'"
  fi

  if command -v cursor >/dev/null 2>&1 && [[ -f "$SSOT/editors/cursor-extensions.txt" ]]; then
    while IFS= read -r ext; do
      [[ -z "$ext" ]] && continue
      if cursor --list-extensions 2>/dev/null | grep -qFx "$ext"; then
        ui_skip "cursor: $ext"
      else
        cursor --install-extension "$ext" --force >/dev/null 2>&1 && { ui_ok "cursor: $ext"; (( installed++ )); }
      fi
    done < "$SSOT/editors/cursor-extensions.txt"
  else
    ui_warn "Cursor CLI 없음 — 명령 팔레트에서 'Shell Command: Install cursor command in PATH'"
  fi
  __step_done 10
}

step_11_cli_auth() {
  ui_step_header 11 $TOTAL_STEPS "CLI 인증 (사람 액션)"
  ui_info "각 명령을 별도 터미널에서 실행 후 [y/s/n] 표시"
  echo

  local checks=(
    "gh auth login|gh auth status"
    "gcloud auth list|gcloud auth list 2>/dev/null | grep -q ACTIVE"
    "supabase login|supabase projects list"
    "vercel login|vercel whoami"
    "docker login|docker info"
    "claude (첫 OAuth)|claude config get -g 2>/dev/null"
  )

  for entry in "${checks[@]}"; do
    local cmd="${entry%%|*}"
    local check="${entry##*|}"
    if eval "$check" >/dev/null 2>&1; then
      ui_ok "$cmd ${UI_DIM}(이미 인증)${UI_R}"
    else
      ui_warn "필요: ${UI_BOLD}${UI_CYAN}$cmd${UI_R}"
      if ui_ask_yn "    완료했음?" "y"; then
        ui_ok "$cmd"
      else
        ui_skip "$cmd (나중에)"
      fi
    fi
  done
  __step_done 11
}

step_12_first_project() {
  ui_step_header 12 $TOTAL_STEPS "첫 프로젝트 등록 (선택)"

  if ! ui_ask_yn "    첫 프로젝트를 sync에 등록할까요?" "n"; then
    ui_skip "스킵 (나중에 ${UI_CYAN}cd <project> && project-init${UI_R})"
    __step_done 12
    return
  fi

  local pdir
  pdir=$(ui_ask_input "프로젝트 경로" "$HOME/development")
  if [[ -d "$pdir" ]]; then
    (cd "$pdir" && "$SSOT/bin/project-init.sh")
  else
    ui_err "$pdir 없음 — 스킵"
  fi
  __step_done 12
}

step_13_verify() {
  ui_step_header 13 $TOTAL_STEPS "최종 검증 (bootstrap-doctor)"
  echo
  "$SSOT/bin/bootstrap-doctor.sh"
  __step_done 13
}

# ─── 모드별 흐름 ──────────────────────────────────────────
run_auto() {
  step_01_system_check
  step_02_homebrew
  step_03_1password
  step_04_claude_sync
  step_05_codex
  step_06_secrets
  step_07_npm_bun
  step_08_launchd
  step_09_apps
  step_10_editors
  step_11_cli_auth
  step_12_first_project
  step_13_verify
}

run_step() {
  local n=$1
  case $n in
    1) step_01_system_check ;;
    2) step_02_homebrew ;;
    3) step_03_1password ;;
    4) step_04_claude_sync ;;
    5) step_05_codex ;;
    6) step_06_secrets ;;
    7) step_07_npm_bun ;;
    8) step_08_launchd ;;
    9) step_09_apps ;;
    10) step_10_editors ;;
    11) step_11_cli_auth ;;
    12) step_12_first_project ;;
    13) step_13_verify ;;
    *) ui_err "단계 1~13만 가능"; exit 1 ;;
  esac
}

run_step_by_step() {
  for n in {1..13}; do
    if __is_done $n; then
      ui_skip "단계 $n 이미 완료 — 스킵"
      continue
    fi
    run_step $n
    if (( n < 13 )); then
      ui_ask_yn "    다음 단계 진행?" "y" || { ui_warn "여기서 멈춤. 'mac-setup' 재실행 시 이어서"; return; }
    fi
  done
}

# ─── 진입점 ──────────────────────────────────────────────
main() {
  ui_main_banner

  # 인자 처리
  if [[ $# -gt 0 ]]; then
    case "$1" in
      auto)        run_auto; ui_celebrate "셋업 완료!"; return ;;
      verify)      step_13_verify; return ;;
      reset)       __reset_state; ui_ok "상태 초기화"; return ;;
      --step)      run_step "$2"; return ;;
      -h|--help)
        cat <<EOF
mac-setup [모드]
  (인자 없음)   인터랙티브 모드 선택
  auto          처음부터 끝까지 자동
  verify        검증만 (13단계)
  reset         진행 상태 초기화
  --step N      특정 단계만 (1~13)
EOF
        return ;;
    esac
  fi

  # 인터랙티브 모드 선택
  local completed
  completed=$(jq -r '.completed | length' "$STATE_FILE")
  if (( completed > 0 )); then
    ui_info "이전에 ${UI_BOLD}${completed}/13${UI_R} 단계 완료됨"
  fi

  ui_section "진행 모드"
  printf "      ${UI_BOLD}${UI_PURPLE}1${UI_R}) 처음부터 끝까지 ${UI_DIM}(완료된 단계 자동 스킵)${UI_R}\n"
  printf "      ${UI_BOLD}${UI_PURPLE}2${UI_R}) 단계별 확인 모드 ${UI_DIM}(각 단계마다 yes/no)${UI_R}\n"
  printf "      ${UI_BOLD}${UI_PURPLE}3${UI_R}) 특정 단계만 ${UI_DIM}(번호 입력)${UI_R}\n"
  printf "      ${UI_BOLD}${UI_PURPLE}4${UI_R}) 검증만 ${UI_DIM}(bootstrap-doctor)${UI_R}\n"
  printf "      ${UI_BOLD}${UI_PURPLE}r${UI_R}) 진행 상태 초기화 후 처음부터\n"
  echo

  local mode
  mode=$(ui_ask_input "선택" "1")

  case "$mode" in
    1)
      for n in {1..13}; do
        if __is_done $n; then
          ui_skip "단계 $n 이미 완료 — 스킵"
          continue
        fi
        run_step $n
      done
      ui_celebrate "셋업 완료!"
      ;;
    2) run_step_by_step ;;
    3)
      local n
      n=$(ui_ask_input "단계 번호 (1~13)" "1")
      run_step "$n"
      ;;
    4) step_13_verify ;;
    r)
      __reset_state
      ui_ok "상태 초기화 완료"
      run_auto
      ui_celebrate "셋업 완료!"
      ;;
    *) ui_err "잘못된 선택"; exit 1 ;;
  esac
}

main "$@"
