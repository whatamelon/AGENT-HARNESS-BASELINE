#!/usr/bin/env bash
# omc-cancel-verify — OMC 모드 종료의 검증된 복구 절차 (구조화).
#
# 배경: MCP state_clear 가 경로 해석 오류로 "success" 보고하면서 실제
#       {mode}-state.json 을 안 지우는 버그 → Stop hook 루프 미탈출.
# 이 스크립트는 그 우회를 절차화: 워크스페이스 내 모든 .omc 루트의
# 해당 세션 {mode}-state.json / stop-breaker 를 제거하고 cancel-signal 기록,
# 잔존 0 을 단언한다. MCP 비의존.
#
# usage: omc-cancel-verify.sh <mode> [search_root]
#   mode        : ralph|ultrawork|ultraqa|autopilot|... (필수)
#   search_root : 탐색 시작 (기본: $PWD)
set -euo pipefail

MODE="${1:-}"
ROOT="${2:-$PWD}"
[ -z "$MODE" ] && { echo "usage: omc-cancel-verify.sh <mode> [search_root]" >&2; exit 2; }

NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
EXP="$(python3 -c "from datetime import datetime,timedelta,timezone;print((datetime.now(timezone.utc)+timedelta(seconds=30)).strftime('%Y-%m-%dT%H:%M:%SZ'))")"

removed=0
# 워크스페이스 하위 모든 .omc/state/sessions/*/ 를 대상으로
while IFS= read -r sf; do
  sd="$(dirname "$sf")"
  rm -f "$sf" \
        "$sd/${MODE}-stop-breaker.json" \
        "$sd/skill-active-state.json"
  printf '{"active":true,"requested_at":"%s","expires_at":"%s","mode":"%s","source":"omc-cancel-verify"}' \
    "$NOW" "$EXP" "$MODE" > "$sd/cancel-signal-state.json"
  removed=$((removed + 1))
  echo "cleared: $sf"
done < <(find "$ROOT" -type f -path "*/.omc/state/sessions/*/${MODE}-state.json" 2>/dev/null)

# 단언: 잔존 0
left="$(find "$ROOT" -type f -path "*/.omc/state/sessions/*/${MODE}-state.json" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$left" != "0" ]; then
  echo "ERROR: ${MODE}-state.json still present ($left)" >&2
  find "$ROOT" -type f -path "*/.omc/state/sessions/*/${MODE}-state.json" 2>/dev/null >&2
  exit 1
fi
echo "OK: ${MODE} cleared (${removed} session dir(s)), 0 remaining"
