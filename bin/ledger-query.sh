#!/usr/bin/env bash
# ledger-query.sh — 양 머신 ledger 통합 조회
# 사용법:
#   ledger-query.sh                       모든 이벤트 (시간순)
#   ledger-query.sh --type T              event type 필터
#   ledger-query.sh --persona P           host 필터
#   ledger-query.sh --since 7d            최근 N일/시간
#   ledger-query.sh --format=text         사람 친화 출력

set -uo pipefail

SSOT="$HOME/.config/agent-harness-baseline"
LEDGER_DIR="$SSOT/state/activity"

filter_type=""
filter_persona=""
filter_since=""
format="jsonl"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)     filter_type="$2"; shift 2 ;;
    --persona)  filter_persona="$2"; shift 2 ;;
    --since)    filter_since="$2"; shift 2 ;;
    --format=*) format="${1#--format=}"; shift ;;
    *) echo "알 수 없는 옵션: $1" >&2; exit 1 ;;
  esac
done

# --since 를 절대 시각으로 변환 (ISO8601)
since_ts=""
if [[ -n "$filter_since" ]]; then
  if [[ "$filter_since" =~ ^([0-9]+)([dh])$ ]]; then
    n="${BASH_REMATCH[1]}"
    unit="${BASH_REMATCH[2]}"
    case "$unit" in
      d) since_ts=$(date -v-"${n}"d +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/') ;;
      h) since_ts=$(date -v-"${n}"H +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/') ;;
    esac
  else
    echo "--since 형식: <N>d 또는 <N>h (예: 7d, 4h)" >&2
    exit 1
  fi
fi

# 모든 ledger 파일 합치기
[[ -d "$LEDGER_DIR" ]] || { exit 0; }
all_events=""
for f in "$LEDGER_DIR"/*.jsonl; do
  [[ -f "$f" ]] || continue
  all_events+=$(cat "$f")
  all_events+=$'\n'
done

# 빈 입력 처리
[[ -z "${all_events// /}" ]] && exit 0

# jq 필터 빌드 (--arg 으로 안전하게 파라미터화)
jq_args=()
filter='select(.ts != null)'

if [[ -n "$filter_type" ]]; then
  jq_args+=(--arg ftype "$filter_type")
  filter+=' | select(.type == $ftype)'
fi
if [[ -n "$filter_persona" ]]; then
  jq_args+=(--arg fpersona "$filter_persona")
  filter+=' | select(.host == $fpersona)'
fi
if [[ -n "$since_ts" ]]; then
  jq_args+=(--arg fsince "$since_ts")
  filter+=' | select(.ts >= $fsince)'
fi

# 한 번의 jq 호출로 sort + filter (3-stage pipe 제거)
# set -u 환경에서 빈 배열 확장 방지: ${arr[@]+"${arr[@]}"}
sorted=$(printf '%s' "$all_events" | jq -s -c "${jq_args[@]+"${jq_args[@]}"}" "[.[] | $filter] | sort_by(.ts) | .[]")

if [[ "$format" == "text" ]]; then
  echo "$sorted" | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "$line" | jq -r '"\(.ts) · \(.host) · \(.type)\(if .cwd then " · \(.cwd)" else "" end)\(if .duration_min then " · \(.duration_min)m" else "" end)"'
  done
else
  echo "$sorted"
fi
