#!/usr/bin/env bash
# saas/_lib.sh — SaaS 플러그인 공통 헬퍼
# 모든 __load_<name>() 함수에서 source해서 사용.

# 프로젝트 루트 찾기.
# 현재 디렉터리에서 위로 거슬러 올라가며 .git / package.json / pyproject.toml /
# Cargo.toml / go.mod / .claude-sync.json 중 하나라도 있는 첫 디렉터리.
# 없으면 PWD 반환.
__find_project_root() {
  local d="$PWD"
  while [[ "$d" != "/" && "$d" != "$HOME" ]]; do
    if [[ -d "$d/.git" \
       || -f "$d/package.json" \
       || -f "$d/pyproject.toml" \
       || -f "$d/Cargo.toml" \
       || -f "$d/go.mod" \
       || -f "$d/.claude-sync.json" ]]; then
      echo "$d"
      return 0
    fi
    d="${d:h}"
  done
  echo "$PWD"
}

# 마커 파일 위치 찾기 (C 우선, B fallback).
#
# 사용:
#   __find_marker <plugin-name> <default-suffix> [maxdepth]
#
# 동작:
#   1) 프로젝트 루트의 .claude-sync.json 에 saas.<plugin>.marker 가 있으면 → 그 경로 사용
#   2) 없으면 프로젝트 루트에서 -maxdepth 까지 *<default-suffix> 패턴으로 find
#   3) 둘 다 못 찾으면 빈 문자열
#
# 예: __find_marker supabase "supabase/config.toml" 4
__find_marker() {
  local plugin_name="$1"
  local default_suffix="$2"
  local maxdepth="${3:-3}"

  local proj_root
  proj_root="$(__find_project_root)"

  # 1) C: 명시적 경로
  local meta="$proj_root/.claude-sync.json"
  if [[ -f "$meta" ]]; then
    local explicit
    explicit=$(jq -r --arg k "$plugin_name" '.saas[$k].marker // empty' "$meta" 2>/dev/null)
    if [[ -n "$explicit" && "$explicit" != "null" ]]; then
      local resolved="$proj_root/$explicit"
      if [[ -f "$resolved" ]]; then
        echo "$resolved"
        return 0
      fi
    fi
  fi

  # 2) B: 자동 탐색 (가장 얕은 경로 우선)
  local found
  found=$(find "$proj_root" \
    -maxdepth "$maxdepth" \
    \( -name node_modules -o -name .git -o -name dist -o -name build \) -prune \
    -o -type f -path "*$default_suffix" -print 2>/dev/null \
    | awk '{ print length, $0 }' | sort -n | head -1 | cut -d' ' -f2-)

  [[ -n "$found" ]] && echo "$found"
}

# 명시적 disable 체크.
# .claude-sync.json 에 "saas.<plugin>.disabled": true 면 0 (false) 반환 → 플러그인이 빈 echo로 종료해야 함.
__is_saas_disabled() {
  local plugin_name="$1"
  local proj_root
  proj_root="$(__find_project_root)"
  local meta="$proj_root/.claude-sync.json"
  [[ -f "$meta" ]] || return 1
  local v
  v=$(jq -r --arg k "$plugin_name" '.saas[$k].disabled // false' "$meta" 2>/dev/null)
  [[ "$v" == "true" ]]
}
