#!/usr/bin/env bash
# hud-machines.sh — 두 맥북 상태 단일 라인
# 사용법:
#   hud-machines.sh --format=line       자기/상대 단일 라인
#   hud-machines.sh --no-cache          5s 캐시 무시

set -uo pipefail

SSOT="$HOME/.config/claude-sync"
PERSONA_BIN="$SSOT/bin/persona.sh"
LEDGER_DIR="$SSOT/state/activity"
CACHE_DIR="$SSOT/state/hud-cache"
CACHE_TTL=5

format="line"
use_cache=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format=*) format="${1#--format=}"; shift ;;
    --no-cache) use_cache=0; shift ;;
    *) echo "사용법: hud-machines.sh [--format=line|detail] [--no-cache]" >&2; exit 1 ;;
  esac
done

self_json=$("$PERSONA_BIN" --json 2>/dev/null) || { echo "❌ persona 조회 실패" >&2; exit 1; }
self=$(echo "$self_json" | jq -r '.persona')
self_emoji=$(echo "$self_json" | jq -r '.emoji')
other=$("$PERSONA_BIN" --other 2>/dev/null) || other=""

if [[ "$self" == "홈맥에어" ]]; then
  other_emoji="💼"
else
  other_emoji="🏠"
fi

mkdir -p "$CACHE_DIR"
cache_file="$CACHE_DIR/$self.$format.txt"

if (( use_cache )) && [[ -f "$cache_file" ]]; then
  cache_age=$(( $(date +%s) - $(stat -f %m "$cache_file") ))
  if (( cache_age < CACHE_TTL )); then
    cat "$cache_file"
    exit 0
  fi
fi

other_last_ts=""
if [[ -n "$other" && -f "$LEDGER_DIR/$other.jsonl" ]]; then
  other_last_ts=$(jq -r '.ts' "$LEDGER_DIR/$other.jsonl" 2>/dev/null | sort | tail -1)
fi

other_label=""
if [[ -n "$other_last_ts" && "$other_last_ts" != "null" ]]; then
  # BSD date parsing: format is 2026-04-29T15:03:36+09:00
  # Split on 'T' to isolate date and time parts
  date_part="${other_last_ts%T*}"
  time_part="${other_last_ts#*T}"
  time_only="${time_part:0:8}"          # HH:MM:SS
  tz_raw="${time_part:8}"               # +09:00 or -05:00
  tz_compact="${tz_raw//:/}"            # +0900 or -0500
  other_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "${date_part}T${time_only}${tz_compact}" +%s 2>/dev/null || echo 0)
  now_epoch=$(date +%s)
  diff_sec=$(( now_epoch - other_epoch ))

  if (( diff_sec < 120 )); then
    other_label="✨방금"
  elif (( diff_sec < 1800 )); then
    other_label="⚡$(( diff_sec / 60 ))분"
  elif (( diff_sec < 86400 )); then
    other_label="🕐$(( diff_sec / 3600 ))h"
  elif (( diff_sec < 604800 )); then
    days_ago=$(( diff_sec / 86400 ))
    if (( days_ago == 1 )); then
      other_label="💤어제"
    else
      other_label="💤${days_ago}일전"
    fi
  else
    other_label="🌑"
  fi
fi

if [[ "$format" == "line" ]]; then
  flash_file="$SSOT/state/hud-flash.txt"
  flash_prefix=""
  if [[ -f "$flash_file" ]]; then
    flash_age=$(( $(date +%s) - $(stat -f %m "$flash_file") ))
    if (( flash_age < 5 )); then
      flash_msg=$(cat "$flash_file" 2>/dev/null | head -1)
      if [[ -n "$flash_msg" ]]; then
        flash_prefix="✨ $flash_msg  "
      fi
    fi
  fi

  if [[ -n "$other_label" ]]; then
    out="${flash_prefix}$self_emoji $self ●  $other_emoji $other $other_label"
  else
    out="${flash_prefix}$self_emoji $self ●  $other_emoji $other 🌑"
  fi
  echo "$out" | tee "$cache_file"
elif [[ "$format" == "detail" ]]; then
  today_local=$(date +%Y-%m-%d)
  self_today_commits=0
  self_last_session=""
  self_last_cwd=""
  if [[ -f "$LEDGER_DIR/$self.jsonl" ]]; then
    self_today_commits=$(jq -r --arg d "$today_local" \
      'select(.type == "commit" and (.ts | startswith($d))) | .sha' \
      "$LEDGER_DIR/$self.jsonl" | wc -l | tr -d ' ')
    self_last_session=$(jq -c -r 'select(.type == "session_end") | .' "$LEDGER_DIR/$self.jsonl" | tail -1)
    if [[ -n "$self_last_session" ]]; then
      self_last_cwd=$(echo "$self_last_session" | jq -r '.cwd // ""')
    fi
  fi

  echo "$self_emoji $self ● 활동 중"
  if [[ -n "$self_last_cwd" ]]; then
    echo "   - 마지막: claude session in $self_last_cwd"
  fi
  echo "   - 오늘 commits: ${self_today_commits}개"
  echo ""

  other_today_commits=0
  other_last_session=""
  other_last_cwd=""
  other_last_duration=""
  other_last_msg=""
  if [[ -f "$LEDGER_DIR/$other.jsonl" ]]; then
    other_today_commits=$(jq -r --arg d "$today_local" \
      'select(.type == "commit" and (.ts | startswith($d))) | .sha' \
      "$LEDGER_DIR/$other.jsonl" | wc -l | tr -d ' ')
    other_last_session=$(jq -c -r 'select(.type == "session_end") | .' "$LEDGER_DIR/$other.jsonl" | tail -1)
    if [[ -n "$other_last_session" ]]; then
      other_last_cwd=$(echo "$other_last_session" | jq -r '.cwd // ""')
      other_last_duration=$(echo "$other_last_session" | jq -r '.duration_min // ""')
      other_last_msg=$(echo "$other_last_session" | jq -r '.summary // ""')
    fi
  fi

  if [[ -n "$other_label" ]]; then
    echo "$other_emoji $other $other_label"
  else
    echo "$other_emoji $other 🌑"
  fi
  if [[ -n "$other_last_cwd" ]]; then
    line="   - 마지막: claude session in $other_last_cwd"
    [[ -n "$other_last_duration" ]] && line="$line (${other_last_duration}m)"
    echo "$line"
  fi
  if [[ -n "$other_last_msg" ]]; then
    echo "   - \"$other_last_msg\""
  fi
  echo "   - 오늘 commits: ${other_today_commits}개"
else
  echo "format $format 미지원" >&2
  exit 1
fi
