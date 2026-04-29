#!/usr/bin/env bash
# Supabase SaaS plugin
# 마커: <project>/supabase/config.toml (supabase link로 자동 생성됨)
# 매핑: ~/.config/projects/supabase.json
#   { "<project-ref>": { "token": "op://...", "db_password": "op://..." } }
# Export: SUPABASE_PROJECT_REF, SUPABASE_ACCESS_TOKEN, SUPABASE_DB_PASSWORD

__load_supabase() {
  local map="$HOME/.config/projects/supabase.json"
  local d="$PWD"

  while [[ "$d" != "/" && "$d" != "$HOME" ]]; do
    if [[ -f "$d/supabase/config.toml" && -f "$map" ]]; then
      local pref
      pref=$(grep -E '^project_id' "$d/supabase/config.toml" 2>/dev/null \
             | head -1 | sed 's/.*"\(.*\)".*/\1/')

      if [[ -n "$pref" ]]; then
        local cfg
        cfg=$(jq --arg k "$pref" '.[$k] // empty' "$map" 2>/dev/null)

        if [[ -n "$cfg" && "$cfg" != "null" && "$cfg" != '""' ]]; then
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
        fi
      fi
      break
    fi
    d="${d:h}"
  done
}
