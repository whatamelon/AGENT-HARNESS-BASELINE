#!/usr/bin/env bash
# mac-power-mode.sh — 머신 폼팩터별 전원/잠금 프로비저닝 (멱등·복구 가능)
#
# 맥미니 같은 항시가동 헤드리스 박스를 "풀 무인화"로 굳히거나,
# 맥북으로 되돌리거나, 현재 상태를 점검한다.
#
# 사용:
#   mac-power-mode headless        # 풀 무인화 (잠자기/잠금 끔 + 정전복구 + 원격깨우기 [+ 자동로그인])
#   mac-power-mode laptop          # 노트북 안전 기본값으로 복귀
#   mac-power-mode status          # 현재 전원/잠금/자동로그인 상태 출력
#   mac-power-mode headless --yes  # 자동로그인까지 비대화식 (AUTLOGIN_PW 환경변수 필요)
#
# headless 의 자동로그인은 FileVault 가 꺼져 있을 때만 가능하며 기본은 묻고 진행.
# 모든 변경은 `mac-power-mode laptop` 으로 되돌릴 수 있다.

set -uo pipefail

readonly SSOT="${HOME}/.config/agent-harness-baseline"
readonly MACHINE_FILE="${SSOT}/.machine.json"

# ─── UI (자체 정의 — ui-lib 는 zsh 전용이라 bash 3.2 호환 위해 미사용) ─
ui_ok()    { printf "  \033[32m✓\033[0m %s\n" "$*"; }
ui_warn()  { printf "  \033[33m⚠\033[0m %s\n" "$*"; }
ui_err()   { printf "  \033[31m✗\033[0m %s\n" "$*"; }
ui_info()  { printf "  \033[36mℹ\033[0m %s\n" "$*"; }
ui_doing() { printf "  \033[35m◆\033[0m %s ...\n" "$*"; }
ui_skip()  { printf "  \033[90m⊘ %s\033[0m\n" "$*"; }

_section() { printf "\n\033[1m══ %s ══\033[0m\n" "$*"; }

# ─── 헬퍼 ─────────────────────────────────────────────────
_filevault_on() {
  fdesetup status 2>/dev/null | grep -q "FileVault is On"
}

_current_user() {
  # 콘솔에 로그인한 실제 사용자 (sudo 로 실행돼도 원 사용자)
  echo "${SUDO_USER:-$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || whoami)}"
}

# pmset 키를 하나씩 적용 — 한 키가 무효여도 나머지는 진행
_pmset_apply() {
  local key="$1" val="$2"
  if sudo pmset -a "$key" "$val" 2>/dev/null; then
    ui_ok "pmset -a ${key} ${val}"
  else
    ui_warn "pmset ${key} 적용 실패 (이 macOS 에서 미지원 키일 수 있음 — 스킵)"
  fi
}

# /etc/kcpassword 생성 (자동로그인용 obfuscated 패스워드)
# 커뮤니티 표준 cipher (xfreebird/kcpassword, Munki 등에서 검증된 11바이트 키).
_write_kcpassword() {
  local pw="$1"
  sudo /usr/bin/perl -e '
    my @key = (0x7D,0x89,0x52,0x23,0x06,0x27,0x92,0x6C,0xFE,0xAF,0x80);
    my $pw  = $ARGV[0];
    my @b   = unpack("C*", $pw);
    # 키 길이의 배수가 되도록 NUL 패딩 (정확한 배수면 키 길이만큼 한 블록 더)
    my $kl = scalar(@key);
    do { push @b, 0; } while (scalar(@b) % $kl != 0);
    push @b, (0) x $kl if (length($pw) % $kl == 0);
    my @out;
    for my $i (0 .. $#b) { push @out, $b[$i] ^ $key[$i % $kl]; }
    open(my $fh, ">", "/etc/kcpassword") or die "open /etc/kcpassword: $!";
    binmode($fh);
    print $fh pack("C*", @out);
    close($fh);
  ' "$pw" && sudo /bin/chmod 600 /etc/kcpassword && sudo /usr/sbin/chown root:wheel /etc/kcpassword
}

# ─── HEADLESS (풀 무인화) ─────────────────────────────────
do_headless() {
  local noninteractive="${1:-}"

  _section "전원: 절대 잠들지 않음"
  _pmset_apply sleep 0          # 시스템 잠자기 끔
  _pmset_apply displaysleep 0   # 디스플레이 잠자기 끔 (헤드리스면 무관하나 명시)
  _pmset_apply disksleep 0      # 디스크 잠자기 끔
  _pmset_apply powernap 1       # Power Nap 유지 (백그라운드 유지)
  _pmset_apply womp 1           # Wake on network access (원격 깨우기)
  _pmset_apply autorestart 1    # 정전 후 자동 재시작
  _pmset_apply standby 0        # standby 진입 안 함
  _pmset_apply networkoversleep 0

  _section "잠금: 화면보호기/콘솔 잠금 해제"
  local u; u="$(_current_user)"
  # 화면보호기 자체를 끔(idleTime 0) → 잠금 트리거 원천 차단
  if sudo -u "$u" defaults -currentHost write com.apple.screensaver idleTime -int 0 2>/dev/null; then
    ui_ok "화면보호기 끔 (idleTime 0)"
  else
    ui_warn "화면보호기 설정 실패 (사용자 ${u})"
  fi
  sudo -u "$u" defaults -currentHost write com.apple.screensaver askForPassword -int 0 2>/dev/null \
    && ui_ok "잠금 시 비밀번호 요구 끔" || ui_warn "askForPassword 설정 실패"
  sudo -u "$u" defaults -currentHost write com.apple.screensaver askForPasswordDelay -int 0 2>/dev/null || true

  _section "부팅 시 자동 로그인"
  if _filevault_on; then
    ui_warn "FileVault 가 켜져 있음 — 자동 로그인 불가 (부팅 시 디스크 잠금해제 암호가 필요)."
    ui_info "무인 재부팅까지 원하면: 시스템 설정 → 개인정보 보호 및 보안 → FileVault 끄기 후 재실행"
    ui_info "지금도 '잠자기 안 함 + 콘솔 잠금 안 함' 은 적용됨 (부팅된 상태에서 원격 접근 가능)"
  else
    local do_login="n"
    if [[ "$noninteractive" == "--yes" ]]; then
      do_login="y"
    else
      printf "  \033[33m?\033[0m 재부팅 시 자동 로그인까지 설정할까? (콘솔 물리접근 시 무방비) [y/\033[1mN\033[0m] "
      read -r do_login
      do_login="${do_login:-n}"
    fi
    if [[ "$do_login" =~ ^[Yy]$ ]]; then
      local u pw
      u="$(_current_user)"
      if [[ -n "${AUTOLOGIN_PW:-}" ]]; then
        pw="$AUTOLOGIN_PW"
      else
        printf "  \033[33m?\033[0m '%s' 로그인 비밀번호 (자동로그인용, 화면 미표시): " "$u"
        read -rs pw; echo
      fi
      if [[ -z "$pw" ]]; then
        ui_warn "비밀번호 미입력 — 자동 로그인 스킵 (잠자기/잠금 해제는 적용됨)"
      else
        sudo defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser "$u" 2>/dev/null
        sudo defaults write /Library/Preferences/com.apple.loginwindow autoLoginUserScreenLocked -bool false 2>/dev/null || true
        if _write_kcpassword "$pw"; then
          ui_ok "자동 로그인 설정 완료 (사용자 ${u}) — 다음 재부팅부터 적용"
          ui_info "검증: 한 번 재부팅 후 콘솔이 암호 없이 데스크톱까지 진입하는지 확인"
        else
          ui_err "/etc/kcpassword 생성 실패 — 자동 로그인 미적용 (autoLoginUser 키는 해제 권장: mac-power-mode laptop)"
        fi
        unset pw
      fi
    else
      ui_skip "자동 로그인 스킵 (잠자기/잠금 해제만 적용)"
    fi
  fi

  _record_machine_type "macmini-headless"
  _section "완료"
  ui_ok "풀 무인화 적용됨. 되돌리려면: \033[36mmac-power-mode laptop\033[0m"
  ui_info "현재 상태 확인: mac-power-mode status"
}

# ─── LAPTOP (안전 기본값 복귀) ────────────────────────────
do_laptop() {
  _section "전원: 노트북 기본값 복귀"
  _pmset_apply sleep 1
  _pmset_apply displaysleep 10
  _pmset_apply disksleep 10
  _pmset_apply powernap 1
  _pmset_apply womp 0
  _pmset_apply autorestart 0
  _pmset_apply standby 1

  _section "잠금: 화면보호기/콘솔 잠금 복원"
  local u; u="$(_current_user)"
  sudo -u "$u" defaults -currentHost write com.apple.screensaver idleTime -int 1200 2>/dev/null \
    && ui_ok "화면보호기 20분 복원" || ui_warn "idleTime 복원 실패"
  sudo -u "$u" defaults -currentHost write com.apple.screensaver askForPassword -int 1 2>/dev/null \
    && ui_ok "잠금 시 비밀번호 요구 켬" || ui_warn "askForPassword 복원 실패"
  sudo -u "$u" defaults -currentHost write com.apple.screensaver askForPasswordDelay -int 0 2>/dev/null || true

  _section "자동 로그인 해제"
  if sudo defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser >/dev/null 2>&1; then
    sudo defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || true
    ui_ok "autoLoginUser 키 제거"
  else
    ui_skip "autoLoginUser 미설정"
  fi
  if [[ -f /etc/kcpassword ]]; then
    sudo /bin/rm -f /etc/kcpassword && ui_ok "/etc/kcpassword 삭제"
  else
    ui_skip "/etc/kcpassword 없음"
  fi

  _record_machine_type "laptop"
  _section "완료"
  ui_ok "노트북 안전 기본값으로 복귀됨."
}

# ─── STATUS ───────────────────────────────────────────────
do_status() {
  _section "머신 프로파일"
  if [[ -f "$MACHINE_FILE" ]]; then
    local mt
    mt="$(/usr/bin/jq -r '.machineType // "미설정"' "$MACHINE_FILE" 2>/dev/null || echo '미설정')"
    ui_info "machineType: ${mt}  (persona: $(/usr/bin/jq -r '.persona // "?"' "$MACHINE_FILE" 2>/dev/null))"
  else
    ui_info "machineType: .machine.json 없음"
  fi

  _section "전원 (pmset)"
  pmset -g 2>/dev/null | grep -Ei ' (sleep|displaysleep|disksleep|powernap|womp|autorestart|standby) ' \
    | sed 's/^ */  /' || ui_warn "pmset 조회 실패"

  _section "잠금 / 화면보호기"
  local idle ask
  idle="$(defaults -currentHost read com.apple.screensaver idleTime 2>/dev/null || echo '기본값')"
  ask="$(defaults -currentHost read com.apple.screensaver askForPassword 2>/dev/null || echo '기본값')"
  ui_info "screensaver idleTime: ${idle}  (0=비활성)"
  ui_info "잠금 시 비밀번호(askForPassword): ${ask}  (0=요구안함)"

  _section "자동 로그인 / FileVault"
  local al
  al="$(defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || echo '미설정 또는 확인불가')"
  ui_info "autoLoginUser: ${al}"
  [[ -f /etc/kcpassword ]] && ui_info "/etc/kcpassword: 존재" || ui_info "/etc/kcpassword: 없음"
  ui_info "FileVault: $(fdesetup status 2>/dev/null | head -1)"
}

# ─── .machine.json 에 machineType 기록 (비파괴) ────────────
_record_machine_type() {
  local mt="$1"
  command -v jq >/dev/null 2>&1 || { ui_warn "jq 없음 — machineType 기록 스킵"; return 0; }
  [[ -f "$MACHINE_FILE" ]] || echo '{}' > "$MACHINE_FILE"
  local tmp
  tmp="$(mktemp)"
  if jq --arg mt "$mt" '.machineType = $mt' "$MACHINE_FILE" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$MACHINE_FILE"
    ui_ok ".machine.json machineType=${mt} 기록"
  else
    rm -f "$tmp"
    ui_warn ".machine.json 갱신 실패"
  fi
}

usage() {
  cat <<'EOF'
mac-power-mode <command>

  headless [--yes]   풀 무인화 — 잠자기/디스플레이/디스크 잠자기 끔,
                     정전 후 자동재시작, 원격 깨우기, 콘솔 잠금 해제,
                     (선택) 부팅 시 자동 로그인. 맥미니 등 항시가동 박스용.
  laptop             노트북 안전 기본값으로 전부 복귀 (자동로그인/kcpassword 제거).
  status             현재 전원/잠금/자동로그인/FileVault 상태 출력.

비대화식: AUTOLOGIN_PW=... mac-power-mode headless --yes
EOF
}

main() {
  case "${1:-}" in
    headless) shift; do_headless "${1:-}" ;;
    laptop)   do_laptop ;;
    status)   do_status ;;
    -h|--help|help|"") usage ;;
    *) ui_err "알 수 없는 명령: $1"; echo; usage; exit 1 ;;
  esac
}

main "$@"
