#!/usr/bin/env zsh
# install-apps.sh — 앱 설치 sub-마법사
# 사용: install-apps [preset]   # preset: minimal | recommended | full | custom
# data: ~/.config/agent-harness-baseline/bootstrap/apps.json

set -uo pipefail

readonly SSOT="$HOME/.config/agent-harness-baseline"
readonly DATA="$SSOT/bootstrap/apps.json"
source "$SSOT/shell/ui-lib.sh"

[[ -f "$DATA" ]] || { ui_err "apps.json 없음: $DATA"; exit 1; }
command -v jq >/dev/null || { ui_err "jq 필요"; exit 1; }
command -v brew >/dev/null || { ui_err "brew 필요"; exit 1; }

# 카테고리 출력
__list_categories() {
  jq -r '.categories | to_entries[] | "\(.key)|\(.value.icon) \(.value.name)|\(.value.apps | length)"' "$DATA" \
    | while IFS='|' read -r key label count; do
        printf "      ${UI_BOLD}${UI_PURPLE}%-15s${UI_R} %s ${UI_DIM}(%s개)${UI_R}\n" "$key" "$label" "$count"
      done
}

__list_presets() {
  jq -r '.presets | to_entries[] | "\(.key)|\(.value.name)|\(.value.description)"' "$DATA" \
    | while IFS='|' read -r key name desc; do
        printf "      ${UI_BOLD}${UI_PURPLE}%-15s${UI_R} ${UI_BOLD}%s${UI_R}\n      ${UI_DIM}%-15s %s${UI_R}\n\n" "$key" "$name" "" "$desc"
      done
}

# 앱 1개 설치 (멱등)
# return: 0=installed, 1=skipped(이미), 2=manual, 3=error
__install_one() {
  local app_id="$1"
  local data
  data=$(jq -c --arg id "$app_id" '
    .categories | to_entries[] | .value.apps[] | select(.id == $id)
  ' "$DATA" | head -1)

  [[ -z "$data" ]] && { ui_err "unknown app: $app_id"; return 3; }

  local name method cask url note
  name=$(echo "$data"   | jq -r '.name')
  method=$(echo "$data" | jq -r '.method')
  cask=$(echo "$data"   | jq -r '.cask // empty')
  url=$(echo "$data"    | jq -r '.url // empty')
  note=$(echo "$data"   | jq -r '.note // empty')

  case "$method" in
    brew)
      if brew list --cask "$cask" >/dev/null 2>&1; then
        ui_skip "$name (이미 설치됨)"
        return 1
      fi
      ui_doing "$name"
      if brew install --cask "$cask" >/dev/null 2>&1; then
        ui_ok "$name 설치 완료"
        return 0
      else
        ui_err "$name 설치 실패"
        return 3
      fi
      ;;
    direct)
      ui_warn "$name → ${UI_CYAN}$url${UI_R}"
      if ui_ask_yn "    브라우저에서 열까요?" "n"; then
        open "$url"
      fi
      return 2
      ;;
    manual)
      ui_warn "$name — ${UI_DIM}$note${UI_R}"
      return 2
      ;;
    *)
      ui_err "$name: 알 수 없는 method ($method)"
      return 3
      ;;
  esac
}

# 메인 마법사
__main() {
  ui_main_banner
  echo -e "  ${UI_BOLD}${UI_CYAN}📦 앱 설치 마법사${UI_R}\n"

  local preset="${1:-}"
  if [[ -z "$preset" ]]; then
    ui_section "프리셋"
    __list_presets
    printf "      ${UI_BOLD}${UI_PURPLE}custom${UI_R}          ${UI_DIM}카테고리별로 직접 선택${UI_R}\n\n"
    preset=$(ui_ask_input "선택" "recommended")
  fi

  local app_list
  if [[ "$preset" == "custom" ]]; then
    # 카테고리별로 yes/no
    app_list=()
    while IFS= read -r cat_key; do
      local cat_data
      cat_data=$(jq -r --arg k "$cat_key" '.categories[$k] | "\(.icon) \(.name)"' "$DATA")
      ui_section "$cat_data"
      while IFS='|' read -r aid aname; do
        if ui_ask_yn "    ${aname} 설치?" "y"; then
          app_list+=("$aid")
        fi
      done < <(jq -r --arg k "$cat_key" '.categories[$k].apps[] | "\(.id)|\(.name)"' "$DATA")
    done < <(jq -r '.categories | keys[]' "$DATA")
  else
    # 프리셋 검증
    local exists
    exists=$(jq -r --arg p "$preset" '.presets[$p] // empty' "$DATA")
    [[ -z "$exists" ]] && { ui_err "unknown preset: $preset"; return 1; }
    app_list=( $(jq -r --arg p "$preset" '.presets[$p].apps[]' "$DATA") )
  fi

  local total=${#app_list[@]}
  if (( total == 0 )); then
    ui_warn "선택된 앱 없음"
    return 0
  fi

  echo
  ui_section "${UI_BOLD}${total}개 앱 설치 시작${UI_R}"
  echo

  local installed=0 skipped=0 manual=0 failed=0
  local i=0
  for aid in "${app_list[@]}"; do
    (( i++ ))
    printf "    ${UI_DIM}[%2d/%2d]${UI_R} " "$i" "$total"
    __install_one "$aid"
    case $? in
      0) (( installed++ )) ;;
      1) (( skipped++ )) ;;
      2) (( manual++ )) ;;
      3) (( failed++ )) ;;
    esac
  done

  echo
  ui_summary_box \
    "${UI_GREEN}✓ 신규 설치:${UI_R} ${UI_BOLD}$installed${UI_R}" \
    "${UI_GRAY}⊘ 이미 설치:${UI_R} ${UI_BOLD}$skipped${UI_R}" \
    "${UI_AMBER}⚠ 수동 안내:${UI_R} ${UI_BOLD}$manual${UI_R}" \
    "${UI_RED}✗ 실패:${UI_R}      ${UI_BOLD}$failed${UI_R}"
}

__main "$@"
