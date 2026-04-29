#!/usr/bin/env bash
# greet.sh — 첫 인사 모먼트
# 사용법:
#   greet.sh             mac-setup 완료 후 1회 발동 (greeted: false 일 때)
#   greet.sh --replay    강제 재생 (마킹 안 함)
#   greet.sh --skip      마킹만 (시퀀스 skip)
#
# 환경변수:
#   FAST_GREET=1         sleep 단축 (테스트용)

set -uo pipefail

SSOT="${SSOT:-$HOME/.config/claude-sync}"
WIZARD_STATE="$SSOT/state/wizard-state.json"
MACHINE_FILE="$SSOT/.machine.json"
ACTIVITY_DIR="$SSOT/state/activity"

mode="${1:-default}"

# FAST_GREET=1 → sleep 0, 아니면 실제 sleep
if [[ "${FAST_GREET:-0}" == "1" ]]; then
  SLEEP_BEAT=0
else
  SLEEP_BEAT=1
fi

# wizard-state.json 읽기
completed="false"
greeted="false"
if [[ -f "$WIZARD_STATE" ]]; then
  raw_completed=$(jq -r '.completed // false' "$WIZARD_STATE" 2>/dev/null || echo "false")
  # completed 가 배열이면 length>0 을 true 로 간주
  type_check=$(jq -r 'if .completed | type == "array" then "array" elif .completed == true then "bool_true" else "bool_false" end' "$WIZARD_STATE" 2>/dev/null || echo "bool_false")
  case "$type_check" in
    array)
      arr_len=$(jq '.completed | length' "$WIZARD_STATE" 2>/dev/null || echo "0")
      if (( arr_len > 0 )); then
        completed="true"
      else
        completed="false"
      fi
      ;;
    bool_true)  completed="true"  ;;
    bool_false) completed="false" ;;
    *)          completed="false" ;;
  esac
  greeted=$(jq -r '.greeted // false' "$WIZARD_STATE" 2>/dev/null || echo "false")
fi

# greeted 마킹 함수
mark_greeted() {
  if [[ -f "$WIZARD_STATE" ]]; then
    local tmp
    tmp=$(mktemp)
    jq '.greeted = true' "$WIZARD_STATE" > "$tmp" && mv "$tmp" "$WIZARD_STATE"
  else
    # 파일 없으면 새로 생성
    echo '{"completed":false,"greeted":true}' > "$WIZARD_STATE"
  fi
}

# 모드별 진입 조건
case "$mode" in
  --skip)
    mark_greeted
    exit 0
    ;;
  --replay)
    # 항상 재생, 마킹 안 함 (아래 계속)
    ;;
  default)
    [[ "$completed" == "true" ]] || exit 0
    [[ "$greeted" == "false" ]]  || exit 0
    ;;
  *)
    echo "사용법: greet.sh [--replay|--skip]" >&2
    exit 1
    ;;
esac

# ──────────────────────────────────────────────
# 페르소나 정보 읽기
# ──────────────────────────────────────────────
if [[ ! -f "$MACHINE_FILE" ]]; then
  exit 0
fi

self_persona=$(jq -r '.persona // "unknown"' "$MACHINE_FILE")
self_emoji=$(jq -r '.emoji   // ""'          "$MACHINE_FILE")

# 상대 머신
if [[ "$self_persona" == "홈맥에어" ]]; then
  other_persona="회사맥프로"
  other_emoji="💼"
else
  other_persona="홈맥에어"
  other_emoji="🏠"
fi

# ──────────────────────────────────────────────
# Beat 1 — 핸드셰이크 애니메이션 (\r carriage return)
# ──────────────────────────────────────────────
_sleep() { [[ "$SLEEP_BEAT" == "0" ]] || sleep "$SLEEP_BEAT"; }

printf "%s 연결 중..." "$other_emoji"
_sleep
printf "\r\033[K%s → %s 확인 중..." "$other_emoji" "$self_emoji"
_sleep
printf "\r\033[K%s ↔ %s 연결 완료!\n" "$other_emoji" "$self_emoji"
_sleep

# ──────────────────────────────────────────────
# Beat 2 — 환영 배너
# ──────────────────────────────────────────────
echo ""
echo "╭─────────────────────────────────────────╮"
printf "│  %s  안녕, %-30s│\n" "$self_emoji" "${self_persona}!"
echo "│  mac-setup 완료 후 첫 셸 진입이야.       │"
echo "╰─────────────────────────────────────────╯"
echo ""

# ──────────────────────────────────────────────
# Beat 3 — 컨텍스트 핸드오프
# ──────────────────────────────────────────────

# 3-a. 자기 자산 요약 (스킬/규칙/메모리)
skills_count=$(ls "$SSOT/claude/skills/" 2>/dev/null | wc -l | tr -d ' ')
rules_count=$(ls "$SSOT/claude/rules/" 2>/dev/null | grep -c '\.md$' || echo 0)
memory_lines=0
if [[ -f "$HOME/.claude/projects/-Users-denny/memory/MEMORY.md" ]]; then
  memory_lines=$(wc -l < "$HOME/.claude/projects/-Users-denny/memory/MEMORY.md" | tr -d ' ')
fi

echo "  자산: 스킬 ${skills_count}개 · 규칙 ${rules_count}개 · 메모리 ${memory_lines}줄"

# 3-b. 상대 머신 마지막 session_end
other_file="$ACTIVITY_DIR/${other_persona}.jsonl"
last_session_info=""
if [[ -f "$other_file" ]]; then
  last_session=$(grep '"type":"session_end"' "$other_file" 2>/dev/null | tail -1)
  if [[ -n "$last_session" ]]; then
    last_cwd=$(echo "$last_session" | jq -r '.cwd // ""')
    last_summary=$(echo "$last_session" | jq -r '.summary // ""')
    last_dur=$(echo "$last_session" | jq -r '.duration_min // ""')
    last_ts=$(echo "$last_session" | jq -r '.ts // ""')
    last_session_info="${last_ts:0:16} · ${last_cwd} · ${last_dur}분 · ${last_summary}"
  fi
fi

if [[ -n "$last_session_info" ]]; then
  echo ""
  echo "  ${other_emoji} ${other_persona} 마지막 세션:"
  echo "    $last_session_info"
else
  echo ""
  echo "  ${other_emoji} ${other_persona}: 최근 기록 없음"
fi

# 3-c. 다음 명령 추천
echo ""
echo "  다음 명령:"
if [[ -n "${last_cwd:-}" ]] && [[ "$last_cwd" != "" ]]; then
  proj_name=$(basename "$last_cwd")
  echo "    cd $last_cwd"
  echo "    project-init   # $proj_name 컨텍스트 복원"
  echo "    claude         # 작업 재개"
else
  echo "    cd ~/dev"
  echo "    project-init   # 프로젝트 컨텍스트 복원"
  echo "    claude         # 새 작업 시작"
fi

echo ""

# ──────────────────────────────────────────────
# 마킹 (replay 제외)
# ──────────────────────────────────────────────
if [[ "$mode" != "--replay" ]]; then
  mark_greeted
fi
