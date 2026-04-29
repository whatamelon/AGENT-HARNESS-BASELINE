#!/usr/bin/env bash
# activity.sh — 두 맥북 활동 통합 대시보드
# 사용법:
#   activity                    최근 7일 (기본)
#   activity 30d                30일
#   activity today              오늘만
#   activity <project>          프로젝트(cwd basename) 필터
#   activity <persona>          머신(홈맥에어/회사맥프로) 필터
#   activity --tui              fzf 인터랙티브 (Task 5 stub)
#   activity --json             JSONL 출력

set -uo pipefail

SSOT="${SSOT:-$HOME/.config/claude-sync}"
LEDGER_QUERY="$SSOT/bin/ledger-query.sh"

# TUI helper 함수 (--source-only 테스트용)
build_tui_lines() {
  local input="$1"
  echo "$input" | jq -r 'select(.type == "session_end") |
    (if .host == "홈맥에어" then "🏠" else "💼" end) as $e |
    "\(.ts | split("T")[0]) \(.ts | split("T")[1] | split(":") | "\(.[0]):\(.[1])")  \($e) \(.cwd // "?" | split("/") | last) · \((.duration_min // 0) | tostring)m" + (if .summary then " · \"\(.summary)\"" else "" end)' \
    2>/dev/null | sort -r
}

# --source-only 모드 (build_tui_lines 등 함수만 export)
if [[ "${1:-}" == "--source-only" ]]; then
  return 0 2>/dev/null || exit 0
fi

# 인자 파싱
since="7d"
filter_persona=""
filter_project=""
mode="text"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tui)    mode="tui"; shift ;;
    --json)   mode="json"; shift ;;
    today)    since="1d"; shift ;;
    홈맥에어|회사맥프로) filter_persona="$1"; shift ;;
    [0-9]*d|[0-9]*h)  since="$1"; shift ;;
    *)        filter_project="$1"; shift ;;
  esac
done

# ledger-query 인자 합치기
query_args=(--since "$since")
[[ -n "$filter_persona" ]] && query_args+=(--persona "$filter_persona")

# JSONL 가져오기 (시간순)
events=$("$LEDGER_QUERY" "${query_args[@]}" 2>/dev/null || true)

# project 필터 (basename(cwd) match)
if [[ -n "$filter_project" && -n "$events" ]]; then
  events=$(echo "$events" | jq -c --arg p "$filter_project" \
    'select(.cwd != null and (.cwd | split("/") | last | contains($p)))' 2>/dev/null || true)
fi

# JSON 모드
if [[ "$mode" == "json" ]]; then
  echo "$events"
  exit 0
fi

# TUI 모드 분기 (mode=tui)
if [[ "$mode" == "tui" ]]; then
  if ! command -v fzf >/dev/null; then
    echo "⚠ fzf 미설치 — plain text fallback" >&2
    mode="text"
  else
    lines=$(build_tui_lines "$events")
    if [[ -z "$lines" ]]; then
      echo "(활동 없음)"
      exit 0
    fi
    selected=$(echo "$lines" | fzf \
      --height 50% --reverse \
      --header="↑↓ 세션 / Enter 자세 / q 종료" \
      --preview="echo {} | sed -E 's/.*· (.+)/\\1/'" \
      --preview-window=up:3:wrap)
    [[ -n "$selected" ]] && echo "$selected"
    exit 0
  fi
fi

# ─── 텍스트 모드 ──────────────────────────────────────────────────────────────

# since 라벨 변환 (7d → 7일, 1d → 오늘, 4h → 4시간)
since_label() {
  local s="$1"
  case "$s" in
    1d) echo "오늘" ;;
    *d) echo "${s%d}일" ;;
    *h) echo "${s%h}시간" ;;
    *)  echo "$s" ;;
  esac
}

human_duration() {
  local m="$1"
  if (( m >= 60 )); then
    printf "%dh%dm" $(( m / 60 )) $(( m % 60 ))
  else
    printf "%dm" "$m"
  fi
}

# 헤더 집계
total_duration=0
total_commits=0
if [[ -n "$events" ]]; then
  total_duration=$(echo "$events" | jq -s '[.[] | select(.type == "session_end") | (.duration_min // 0)] | add // 0' 2>/dev/null || echo 0)
  total_commits=$(echo "$events" | jq -s '[.[] | select(.type == "session_end") | (.commits // 0)] | add // 0' 2>/dev/null || echo 0)
fi

echo "═══════════════════════════════════════════════════════════"
printf "   두 맥북 · 최근 %s · 총 %s · %d commits\n" "$(since_label "$since")" "$(human_duration "${total_duration:-0}")" "${total_commits:-0}"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [[ -z "$events" ]]; then
  echo "(활동 없음)"
  # 통계 섹션도 출력 (빈 상태로)
  echo ""
  echo "[ 통계 ] 요일별 활동 시간"
  printf "   월 %s  화 %s  수 %s  목 %s  금 %s  토 %s  일 %s\n" \
    "░░░░░" "░░░░░" "░░░░░" "░░░░░" "░░░░░" "░░░░░" "░░░░░"
  exit 0
fi

# 일자별 그룹 (newest first)
today=$(date +%Y-%m-%d)
yesterday=$(date -v-1d +%Y-%m-%d)

days=$(echo "$events" | jq -r '.ts | split("T")[0]' | sort -ur)

for day in $days; do
  day_label="${day:5}"  # MM-DD
  if [[ "$day" == "$today" ]]; then
    day_label="$day_label (오늘)"
  elif [[ "$day" == "$yesterday" ]]; then
    day_label="$day_label (어제)"
  fi

  # 그날 머신별 시간 합계
  home_min=$(echo "$events" | jq -s --arg d "$day" \
    '[.[] | select(.type == "session_end" and .host == "홈맥에어" and (.ts | startswith($d))) | (.duration_min // 0)] | add // 0' 2>/dev/null || echo 0)
  work_min=$(echo "$events" | jq -s --arg d "$day" \
    '[.[] | select(.type == "session_end" and .host == "회사맥프로" and (.ts | startswith($d))) | (.duration_min // 0)] | add // 0' 2>/dev/null || echo 0)

  printf "📅 %s   🏠 %s + 💼 %s\n" "$day_label" "$(human_duration "${home_min:-0}")" "$(human_duration "${work_min:-0}")"

  # 그날 세션들 newest first
  echo "$events" | jq -c --arg d "$day" \
    'select(.type == "session_end" and (.ts | startswith($d)))' 2>/dev/null \
  | jq -s -r 'sort_by(.ts) | reverse | .[] |
       (if .host == "홈맥에어" then "🏠" else "💼" end) as $e |
       "       \(.ts | split("T")[1] | split(":") | "\(.[0]):\(.[1])")  \($e) \(.cwd // "?" | split("/") | last) · \((.duration_min // 0) | tostring)m" + (if .summary then " · \"\(.summary)\"" else "" end)' \
    2>/dev/null || true

  echo ""
done

# ─── 통계 위젯 ────────────────────────────────────────────────────────────────

echo "[ 통계 ] 요일별 활동 시간"

# bash 3.2 호환 — assoc array 없음. 7개 변수 사용
d_mon=0; d_tue=0; d_wed=0; d_thu=0; d_fri=0; d_sat=0; d_sun=0

if [[ -n "$events" ]]; then
  while IFS=$'\t' read -r ts dur; do
    [[ -z "$ts" || "$ts" == "null" ]] && continue
    day_part="${ts%%T*}"
    # BSD date: %u (1=Mon..7=Sun)
    wday=$(date -j -f "%Y-%m-%d" "$day_part" +%u 2>/dev/null || echo 0)
    case "$wday" in
      1) d_mon=$(( d_mon + dur )) ;;
      2) d_tue=$(( d_tue + dur )) ;;
      3) d_wed=$(( d_wed + dur )) ;;
      4) d_thu=$(( d_thu + dur )) ;;
      5) d_fri=$(( d_fri + dur )) ;;
      6) d_sat=$(( d_sat + dur )) ;;
      7) d_sun=$(( d_sun + dur )) ;;
    esac
  done < <(echo "$events" | jq -r 'select(.type == "session_end") | "\(.ts)\t\(.duration_min // 0)"')
fi

# 막대 출력 — 최대값 기준 0~5 칸
max_min=$(printf "%d\n%d\n%d\n%d\n%d\n%d\n%d\n" "$d_mon" "$d_tue" "$d_wed" "$d_thu" "$d_fri" "$d_sat" "$d_sun" | sort -n | tail -1)
[[ -z "$max_min" || "$max_min" -le 0 ]] && max_min=1

bar_for() {
  local min="$1"
  local n=$(( min * 5 / max_min ))
  (( n > 5 )) && n=5
  (( n < 0 )) && n=0
  local bar=""
  local i
  for ((i=0; i<n; i++)); do bar+="▓"; done
  for ((i=n; i<5; i++)); do bar+="░"; done
  printf "%s" "$bar"
}

printf "   월 %s  화 %s  수 %s  목 %s  금 %s  토 %s  일 %s\n" \
  "$(bar_for $d_mon)" "$(bar_for $d_tue)" "$(bar_for $d_wed)" \
  "$(bar_for $d_thu)" "$(bar_for $d_fri)" "$(bar_for $d_sat)" "$(bar_for $d_sun)"

# 모멘텀 (어제 대비)
today_iso=$(date +%Y-%m-%d)
yest_iso=$(date -v-1d +%Y-%m-%d)
today_min=$(echo "$events" | jq -s --arg d "$today_iso" \
  '[.[] | select(.type == "session_end" and (.ts | startswith($d))) | (.duration_min // 0)] | add // 0' 2>/dev/null || echo 0)
yest_min=$(echo "$events" | jq -s --arg d "$yest_iso" \
  '[.[] | select(.type == "session_end" and (.ts | startswith($d))) | (.duration_min // 0)] | add // 0' 2>/dev/null || echo 0)

today_min=${today_min:-0}
yest_min=${yest_min:-0}

if (( yest_min > 0 )); then
  pct=$(( (today_min - yest_min) * 100 / yest_min ))
  if (( pct > 0 )); then
    printf "[ 모멘텀 ] 어제 대비 +%d%% (오늘 %dm vs 어제 %dm)\n" "$pct" "$today_min" "$yest_min"
  elif (( pct < 0 )); then
    printf "[ 모멘텀 ] 어제 대비 %d%% (오늘 %dm vs 어제 %dm)\n" "$pct" "$today_min" "$yest_min"
  else
    printf "[ 모멘텀 ] 어제와 동일 (%dm)\n" "$today_min"
  fi
elif (( today_min > 0 )); then
  printf "[ 모멘텀 ] 오늘 %dm (어제는 0m)\n" "$today_min"
fi
