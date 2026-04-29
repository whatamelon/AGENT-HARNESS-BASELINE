#!/usr/bin/env zsh
# ui-lib.sh — 휘황찬란 터미널 UI 헬퍼 라이브러리
# 사용: source "$HOME/.config/claude-sync/shell/ui-lib.sh"

# ──── Truecolor 팔레트 ────────────────────────────────────
typeset -g UI_ROSE='\033[38;2;255;105;180m'      # 핫핑크
typeset -g UI_MAGENTA='\033[38;2;236;72;153m'    # 마젠타
typeset -g UI_PURPLE='\033[38;2;168;85;247m'     # 보라
typeset -g UI_VIOLET='\033[38;2;139;92;246m'     # 바이올렛
typeset -g UI_INDIGO='\033[38;2;99;102;241m'     # 인디고
typeset -g UI_SKY='\033[38;2;56;189;248m'        # 하늘
typeset -g UI_CYAN='\033[38;2;34;211;238m'       # 시안
typeset -g UI_TEAL='\033[38;2;20;184;166m'       # 틸
typeset -g UI_LIME='\033[38;2;163;230;53m'       # 라임
typeset -g UI_EMERALD='\033[38;2;52;211;153m'    # 에메랄드
typeset -g UI_GREEN='\033[38;2;34;197;94m'       # 초록
typeset -g UI_AMBER='\033[38;2;251;191;36m'      # 황금
typeset -g UI_ORANGE='\033[38;2;249;115;22m'     # 주황
typeset -g UI_CORAL='\033[38;2;251;113;133m'     # 산호
typeset -g UI_RED='\033[38;2;239;68;68m'         # 빨강
typeset -g UI_GRAY='\033[38;2;156;163;175m'      # 회색
typeset -g UI_DIM='\033[2m'
typeset -g UI_BOLD='\033[1m'
typeset -g UI_ITAL='\033[3m'
typeset -g UI_UNDER='\033[4m'
typeset -g UI_REV='\033[7m'
typeset -g UI_R='\033[0m'

# 배경색 (액센트용)
typeset -g UI_BG_ROSE='\033[48;2;255;105;180m'
typeset -g UI_BG_PURPLE='\033[48;2;168;85;247m'
typeset -g UI_BG_GOLD='\033[48;2;251;191;36m'
typeset -g UI_BG_DARK='\033[48;2;30;30;40m'

# ──── 그라데이션 텍스트 ────────────────────────────────────
ui_gradient() {
  local text="$1"
  local from_r=${2:-255} from_g=${3:-105} from_b=${4:-180}
  local to_r=${5:-99}    to_g=${6:-102}    to_b=${7:-241}
  local len=${#text}
  [[ $len -eq 0 ]] && return
  local i=0
  while (( i < len )); do
    local ratio=$(( i * 100 / len ))
    local r=$(( from_r + (to_r - from_r) * i / len ))
    local g=$(( from_g + (to_g - from_g) * i / len ))
    local b=$(( from_b + (to_b - from_b) * i / len ))
    printf "\033[1;38;2;${r};${g};${b}m${text:$i:1}"
    (( i++ ))
  done
  printf "${UI_R}"
}

# ──── 박스/구분선 ────────────────────────────────────────
ui_hr() {
  local width=${1:-72}
  local color=${2:-$UI_PURPLE}
  printf "${color}"
  printf '━%.0s' $(seq 1 $width)
  printf "${UI_R}\n"
}

ui_hr_dim() {
  local width=${1:-72}
  printf "${UI_DIM}${UI_GRAY}"
  printf '─%.0s' $(seq 1 $width)
  printf "${UI_R}\n"
}

# 큰 시작 배너 (개발환경 꾸쮹)
ui_main_banner() {
  echo
  echo -e "${UI_BOLD}${UI_ROSE}    ╔══════════════════════════════════════════════════════════╗${UI_R}"
  echo -e "${UI_BOLD}${UI_ROSE}    ║${UI_R}                                                          ${UI_BOLD}${UI_ROSE}║${UI_R}"
  printf "${UI_BOLD}${UI_ROSE}    ║${UI_R}            "
  ui_gradient "✦  개발환경 꾸쮹  ✦" 255 105 180 99 102 241
  echo -e "             ${UI_BOLD}${UI_ROSE}║${UI_R}"
  echo -e "${UI_BOLD}${UI_ROSE}    ║${UI_R}        ${UI_DIM}${UI_GRAY}─────────────────────────────────────────${UI_R}         ${UI_BOLD}${UI_ROSE}║${UI_R}"
  echo -e "${UI_BOLD}${UI_ROSE}    ║${UI_R}            ${UI_CYAN}${UI_ITAL}Mac Setup Wizard${UI_R}  ${UI_DIM}·${UI_R}  ${UI_AMBER}claude-sync v1.0${UI_R}            ${UI_BOLD}${UI_ROSE}║${UI_R}"
  echo -e "${UI_BOLD}${UI_ROSE}    ║${UI_R}                                                          ${UI_BOLD}${UI_ROSE}║${UI_R}"
  echo -e "${UI_BOLD}${UI_ROSE}    ╚══════════════════════════════════════════════════════════╝${UI_R}"
  echo
}

# 단계 헤더 (──── 5/13 · 시크릿 자동 주입 ────)
ui_step_header() {
  local n="$1" total="$2" title="$3"
  echo
  printf "${UI_DIM}${UI_GRAY}━━━━${UI_R} "
  printf "${UI_BOLD}${UI_PURPLE}%s${UI_R}${UI_DIM}/%s${UI_R} ${UI_DIM}·${UI_R} " "$n" "$total"
  printf "${UI_BOLD}${UI_CYAN}%s${UI_R}" "$title"
  printf " ${UI_DIM}${UI_GRAY}"
  local pad=$((50 - ${#title}))
  (( pad > 0 )) && printf '━%.0s' $(seq 1 $pad)
  printf "${UI_R}\n"
}

# 작은 섹션 (서브타이틀)
ui_section() {
  echo
  printf "  ${UI_BOLD}${UI_VIOLET}▸${UI_R} ${UI_BOLD}%s${UI_R}\n" "$*"
}

# ──── 상태 메시지 ─────────────────────────────────────────
ui_ok()    { printf "    ${UI_GREEN}✓${UI_R} %s\n" "$*"; }
ui_warn()  { printf "    ${UI_AMBER}⚠${UI_R} %s\n" "$*"; }
ui_err()   { printf "    ${UI_RED}✗${UI_R} %s\n" "$*"; }
ui_info()  { printf "    ${UI_SKY}ℹ${UI_R} %s\n" "$*"; }
ui_skip()  { printf "    ${UI_GRAY}⊘${UI_R} ${UI_DIM}%s${UI_R}\n" "$*"; }
ui_doing() { printf "    ${UI_PURPLE}◆${UI_R} %s ${UI_DIM}...${UI_R}\n" "$*"; }
ui_arrow() { printf "    ${UI_CYAN}→${UI_R} ${UI_DIM}%s${UI_R}\n" "$*"; }

# ──── 입력/대기 ──────────────────────────────────────────
ui_pause() {
  local msg="${1:-계속하려면 ENTER}"
  echo
  printf "    ${UI_DIM}${UI_AMBER}⏎${UI_R}  ${UI_DIM}${msg}${UI_R} "
  read -r _
}

ui_ask_yn() {
  local prompt="$1"
  local default="${2:-y}"   # y or n
  local hint
  [[ "$default" == "y" ]] && hint="${UI_BOLD}Y${UI_R}/n" || hint="y/${UI_BOLD}N${UI_R}"
  printf "    ${UI_AMBER}?${UI_R} ${prompt} ${UI_DIM}[${hint}${UI_DIM}]${UI_R} "
  read -r ans
  ans="${ans:-$default}"
  [[ "$ans" =~ ^[Yy]$ ]]
}

ui_ask_select() {
  # ui_ask_select "프롬프트" "옵션1" "옵션2" "옵션3"
  local prompt="$1"; shift
  local options=("$@")
  local i=1
  echo
  for opt in "${options[@]}"; do
    printf "      ${UI_BOLD}${UI_PURPLE}%d${UI_R}) %s\n" "$i" "$opt"
    (( i++ ))
  done
  echo
  printf "    ${UI_AMBER}?${UI_R} ${prompt} ${UI_DIM}[1]${UI_R} "
  read -r choice
  choice="${choice:-1}"
  echo "$choice"
}

ui_ask_input() {
  local prompt="$1" default="$2"
  if [[ -n "$default" ]]; then
    printf "    ${UI_AMBER}?${UI_R} ${prompt} ${UI_DIM}[${default}]${UI_R} "
  else
    printf "    ${UI_AMBER}?${UI_R} ${prompt} "
  fi
  read -r val
  echo "${val:-$default}"
}

# ──── 프로그레스 ──────────────────────────────────────────
ui_progress() {
  local cur=$1 total=$2 width=${3:-30}
  local pct=$(( cur * 100 / total ))
  local fill=$(( cur * width / total ))
  local empty=$(( width - fill ))
  printf "    ${UI_PURPLE}"
  printf '█%.0s' $(seq 1 $fill 2>/dev/null)
  printf "${UI_DIM}${UI_GRAY}"
  (( empty > 0 )) && printf '░%.0s' $(seq 1 $empty)
  printf "${UI_R} ${UI_BOLD}%3d%%${UI_R} ${UI_DIM}(%d/%d)${UI_R}\n" "$pct" "$cur" "$total"
}

# 줄바꿈 없이 진행 표시 (반복 갱신)
ui_progress_inline() {
  local cur=$1 total=$2 label="$3" width=${4:-25}
  local pct=$(( cur * 100 / total ))
  local fill=$(( cur * width / total ))
  local empty=$(( width - fill ))
  printf "\r    ${UI_PURPLE}"
  printf '█%.0s' $(seq 1 $fill 2>/dev/null)
  printf "${UI_DIM}${UI_GRAY}"
  (( empty > 0 )) && printf '░%.0s' $(seq 1 $empty)
  printf "${UI_R} ${UI_BOLD}%3d%%${UI_R} ${UI_DIM}%-30s${UI_R}" "$pct" "$label"
}

# ──── 스피너 (백그라운드 명령 대기) ────────────────────────
ui_spinner() {
  # ui_spinner <pid> <메시지>
  local pid=$1
  local msg="$2"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local colors=("$UI_ROSE" "$UI_MAGENTA" "$UI_PURPLE" "$UI_VIOLET" "$UI_INDIGO" "$UI_SKY" "$UI_CYAN" "$UI_TEAL")
  local i=0
  printf "\033[?25l"   # 커서 숨김
  while kill -0 $pid 2>/dev/null; do
    local fi=$(( i % 10 ))
    local ci=$(( i % 8 ))
    printf "\r    ${colors[ci+1]}${frames[fi+1]}${UI_R} ${UI_DIM}%s${UI_R}" "$msg"
    sleep 0.08
    (( i++ ))
  done
  printf "\033[?25h"   # 커서 보이기
  printf "\r                                                                  \r"
}

# ──── 마무리 셀러브레이션 ─────────────────────────────────
ui_celebrate() {
  local msg="${1:-셋업 완료!}"
  echo
  echo -e "        ${UI_AMBER}.${UI_R}    ${UI_ROSE}*${UI_R}    ${UI_PURPLE}.${UI_R}    ${UI_CYAN}*${UI_R}    ${UI_LIME}.${UI_R}    ${UI_AMBER}*${UI_R}"
  echo -e "    ${UI_PURPLE}.${UI_R}    ${UI_AMBER}*${UI_R}    ${UI_ROSE}.${UI_R}    ${UI_CYAN}*${UI_R}    ${UI_PURPLE}.${UI_R}    ${UI_LIME}*${UI_R}    ${UI_ROSE}.${UI_R}"
  echo -e "  ${UI_BOLD}${UI_ROSE}╔══════════════════════════════════════════════════════════╗${UI_R}"
  printf "  ${UI_BOLD}${UI_ROSE}║${UI_R}            "
  ui_gradient "  ✦  ${msg}  ✦  " 251 191 36 255 105 180
  echo -e "             ${UI_BOLD}${UI_ROSE}║${UI_R}"
  echo -e "  ${UI_BOLD}${UI_ROSE}╚══════════════════════════════════════════════════════════╝${UI_R}"
  echo -e "    ${UI_LIME}*${UI_R}    ${UI_PURPLE}.${UI_R}    ${UI_CYAN}*${UI_R}    ${UI_ROSE}.${UI_R}    ${UI_AMBER}*${UI_R}    ${UI_PURPLE}.${UI_R}    ${UI_LIME}*${UI_R}"
  echo -e "        ${UI_AMBER}.${UI_R}    ${UI_ROSE}*${UI_R}    ${UI_PURPLE}.${UI_R}    ${UI_CYAN}*${UI_R}    ${UI_LIME}.${UI_R}"
  echo
}

# ──── 요약 박스 ───────────────────────────────────────────
ui_summary_box() {
  local -a lines=("$@")
  local maxlen=0
  for l in "${lines[@]}"; do
    [[ ${#l} -gt $maxlen ]] && maxlen=${#l}
  done
  local width=$((maxlen + 4))
  echo
  printf "    ${UI_PURPLE}╭"
  printf '─%.0s' $(seq 1 $width)
  printf "╮${UI_R}\n"
  for l in "${lines[@]}"; do
    printf "    ${UI_PURPLE}│${UI_R}  %-${maxlen}s  ${UI_PURPLE}│${UI_R}\n" "$l"
  done
  printf "    ${UI_PURPLE}╰"
  printf '─%.0s' $(seq 1 $width)
  printf "╯${UI_R}\n"
  echo
}
