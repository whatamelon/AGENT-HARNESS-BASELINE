#!/usr/bin/env bash
# summarize-session.sh — 세션 헤드라인 합성
# 사용법: summarize-session.sh <cwd> <duration_min> <commits> <files_changed>

set -uo pipefail

if [[ $# -lt 4 ]]; then
  echo "사용법: summarize-session.sh <cwd> <duration_min> <commits> <files_changed>" >&2
  exit 1
fi

cwd="$1"
duration="$2"
commits="$3"
files="$4"

base=$(basename "$cwd")

last_msg=""
if [[ -d "$cwd/.git" ]]; then
  last_msg=$(git -C "$cwd" log -1 --format=%s 2>/dev/null || true)
fi

parts=("$base")
[[ -n "$last_msg" ]] && parts+=("\"$last_msg\"")
parts+=("${duration}분")
parts+=("$commits commits")
parts+=("$files files")

out=""
for p in "${parts[@]}"; do
  if [[ -z "$out" ]]; then
    out="$p"
  else
    out="$out · $p"
  fi
done

echo "$out"
