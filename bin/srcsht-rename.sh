#!/usr/bin/env bash
# srcsht-rename.sh — ~/srcsht 디렉토리의 스크린샷 파일명을 timestamp로 통일.
# launchd가 ~/srcsht 변경 감지하면 호출 (~/Library/LaunchAgents/com.denny.srcsht-rename.plist).
set -euo pipefail

DIR="$HOME/srcsht"

sleep 0.3

cd "$DIR" 2>/dev/null || exit 0

shopt -s nullglob

for f in *.jpg *.jpeg *.png *.JPG *.JPEG *.PNG; do
  [[ -f "$f" ]] || continue

  if [[ "$f" =~ ^srcsht_[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}(_[0-9]+)?\.(jpg|jpeg|png)$ ]]; then
    continue
  fi

  ts=$(stat -f "%Sm" -t "%Y-%m-%d_%H-%M-%S" "$f")
  ext_lower=$(printf '%s' "${f##*.}" | tr '[:upper:]' '[:lower:]')

  base="srcsht_${ts}"
  target="${base}.${ext_lower}"

  i=2
  while [[ -e "$target" && "$target" != "$f" ]]; do
    target="${base}_${i}.${ext_lower}"
    i=$((i + 1))
  done

  if [[ "$f" != "$target" ]]; then
    mv -n -- "$f" "$target"
    printf '[%s] %s -> %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$f" "$target"
  fi
done
