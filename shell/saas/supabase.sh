#!/usr/bin/env bash
# Supabase SaaS plugin
# 마커: <project>/supabase/config.toml (supabase link로 자동 생성됨)
#       monorepo 시 자동 탐색 (maxdepth 4)
# 매핑: ~/.config/projects/supabase.json
#   { "<project-ref>": { "token": "op://...", "db_password": "op://..." } }
# Export: SUPABASE_PROJECT_REF, SUPABASE_ACCESS_TOKEN, SUPABASE_DB_PASSWORD
#
# 명시적 마커 경로 지정:
#   project-root/.agent-harness-baseline.json
#   { "saas": { "supabase": { "marker": "db/supabase/config.toml" } } }

source "$HOME/.config/agent-harness-baseline/shell/saas/_lib.sh"

__load_supabase() {
  local map="$HOME/.config/projects/supabase.json"
  [[ -f "$map" ]] || return 0
  __is_saas_disabled supabase && return 0

  local marker_file
  marker_file=$(__find_marker supabase "supabase/config.toml" 4)
  [[ -z "$marker_file" ]] && return 0

  local pref
  pref=$(grep -E '^project_id' "$marker_file" 2>/dev/null \
         | head -1 | sed 's/.*"\(.*\)".*/\1/')
  [[ -z "$pref" ]] && return 0

  local cfg
  cfg=$(jq --arg k "$pref" '.[$k] // empty' "$map" 2>/dev/null)
  [[ -z "$cfg" || "$cfg" == "null" || "$cfg" == '""' ]] && return 0

  export SUPABASE_PROJECT_REF="$pref"
  local out="SUPABASE_PROJECT_REF"

  local tref dbref
  tref=$(echo "$cfg" | jq -r '.token // empty')
  dbref=$(echo "$cfg" | jq -r '.db_password // empty')

  if [[ -n "$tref" && "$tref" != "null" ]] && command -v op >/dev/null; then
    export SUPABASE_ACCESS_TOKEN=$(op read "$tref" 2>/dev/null)
    out="$out SUPABASE_ACCESS_TOKEN"
  fi

  if [[ -n "$dbref" && "$dbref" != "null" ]] && command -v op >/dev/null; then
    export SUPABASE_DB_PASSWORD=$(op read "$dbref" 2>/dev/null)
    out="$out SUPABASE_DB_PASSWORD"
  fi

  echo "$out"
}
