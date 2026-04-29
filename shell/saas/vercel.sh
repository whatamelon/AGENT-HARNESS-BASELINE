#!/usr/bin/env bash
# Vercel SaaS plugin
# 마커: <project>/.vercel/project.json (vercel link로 자동 생성됨)
# 매핑: ~/.config/projects/vercel.json
# Export: VERCEL_TOKEN, VERCEL_ORG_ID, VERCEL_PROJECT_ID

__load_vercel() {
  local map="$HOME/.config/projects/vercel.json"
  local d="$PWD"

  while [[ "$d" != "/" && "$d" != "$HOME" ]]; do
    if [[ -f "$d/.vercel/project.json" && -f "$map" ]]; then
      local pid ref
      pid=$(jq -r .projectId "$d/.vercel/project.json" 2>/dev/null)
      ref=$(jq -r --arg k "$pid" '.[$k] // empty' "$map" 2>/dev/null)

      if [[ -n "$ref" && "$ref" != "null" ]] && command -v op >/dev/null; then
        export VERCEL_TOKEN=$(op read "$ref" 2>/dev/null)
        export VERCEL_ORG_ID=$(jq -r .orgId "$d/.vercel/project.json" 2>/dev/null)
        export VERCEL_PROJECT_ID="$pid"
        echo "VERCEL_TOKEN VERCEL_ORG_ID VERCEL_PROJECT_ID"
      fi
      break
    fi
    d="${d:h}"
  done
}
