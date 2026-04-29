#!/usr/bin/env bash
# ledger-append.sh — 활동 ledger에 한 줄 append
# 사용법:
#   ledger-append.sh <event_type> [key=value]...
# 예:
#   ledger-append.sh session_end cwd=/dev/x duration_min=22 commits=3

set -uo pipefail

SSOT="$HOME/.config/claude-sync"
PERSONA_BIN="$SSOT/bin/persona.sh"

if [[ $# -lt 1 ]]; then
  echo "사용법: ledger-append.sh <event_type> [key=value]..." >&2
  exit 1
fi

event_type="$1"
shift

persona=$("$PERSONA_BIN") || { echo "❌ persona 조회 실패" >&2; exit 1; }
ledger_dir="$SSOT/state/activity"
ledger_file="$ledger_dir/$persona.jsonl"
mkdir -p "$ledger_dir"

# 기본 필드 — ts (ISO8601 with timezone), host, type
ts=$(date +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')

json=$(jq -nc \
  --arg ts "$ts" \
  --arg host "$persona" \
  --arg type "$event_type" \
  '{ts:$ts, host:$host, type:$type}')

for pair in "$@"; do
  if [[ "$pair" == *"="* ]]; then
    key="${pair%%=*}"
    value="${pair#*=}"
    if [[ "$value" =~ ^-?[0-9]+$ ]]; then
      json=$(echo "$json" | jq -c --arg k "$key" --argjson v "$value" '. + {($k): $v}')
    else
      json=$(echo "$json" | jq -c --arg k "$key" --arg v "$value" '. + {($k): $v}')
    fi
  fi
done

echo "$json" >> "$ledger_file"
