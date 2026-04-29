#!/usr/bin/env bash
# Vercel SaaS plugin
# 마커: <project>/.vercel/project.json (vercel link로 자동 생성됨)
# 매핑: ~/.config/projects/vercel.json
# Export: VERCEL_TOKEN, VERCEL_ORG_ID, VERCEL_PROJECT_ID
#
# 명시적 마커 경로 지정 (monorepo 등):
#   project-root/.claude-sync.json
#   { "saas": { "vercel": { "marker": "fe/.vercel/project.json" } } }

source "$HOME/.config/claude-sync/shell/saas/_lib.sh"

__load_vercel() {
  local map="$HOME/.config/projects/vercel.json"
  [[ -f "$map" ]] || return 0
  __is_saas_disabled vercel && return 0

  local marker_file
  marker_file=$(__find_marker vercel ".vercel/project.json" 4)
  [[ -z "$marker_file" ]] && return 0

  local pid ref
  pid=$(jq -r .projectId "$marker_file" 2>/dev/null)
  [[ -z "$pid" || "$pid" == "null" ]] && return 0

  ref=$(jq -r --arg k "$pid" '.[$k] // empty' "$map" 2>/dev/null)
  if [[ -n "$ref" && "$ref" != "null" ]] && command -v op >/dev/null; then
    export VERCEL_TOKEN=$(op read "$ref" 2>/dev/null)
    export VERCEL_ORG_ID=$(jq -r .orgId "$marker_file" 2>/dev/null)
    export VERCEL_PROJECT_ID="$pid"
    echo "VERCEL_TOKEN VERCEL_ORG_ID VERCEL_PROJECT_ID"
  fi
}
