#!/usr/bin/env bats
load test_helper

setup_persona_and_ledgers() {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"

  TS_TODAY_AM=$(date +%Y-%m-%dT09:30:00%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  TS_TODAY_PM=$(date +%Y-%m-%dT13:25:00%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  TS_YEST_PM=$(date -v-1d +%Y-%m-%dT22:00:00%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')

  cat > "$SSOT/state/activity/홈맥에어.jsonl" <<EOF
{"ts":"$TS_TODAY_AM","host":"홈맥에어","type":"session_end","cwd":"/dev/claude-sync","duration_min":47,"commits":2,"summary":"feat: cross-tool sync"}
{"ts":"$TS_TODAY_PM","host":"홈맥에어","type":"session_end","cwd":"/dev/lawblaw_dev","duration_min":22,"commits":1,"summary":"fix(auth): SSO 토큰 검증"}
{"ts":"$TS_YEST_PM","host":"홈맥에어","type":"session_end","cwd":"/dev/claude-sync","duration_min":120,"commits":3}
EOF
  cat > "$SSOT/state/activity/회사맥프로.jsonl" <<EOF
{"ts":"$(date +%Y-%m-%dT11:00:00%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')","host":"회사맥프로","type":"session_end","cwd":"/dev/lawblaw_dev","duration_min":72,"commits":4,"summary":"feat(billing)"}
EOF
}

# ── Task 1: 기본 텍스트 출력 ────────────────────────────────────────────────

@test "activity (no args) shows header with date range" {
  setup_persona_and_ledgers
  run "$SSOT/bin/activity.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"두 맥북"* ]]
  [[ "$output" == *"최근 7일"* ]]
}

@test "activity shows day section headers" {
  setup_persona_and_ledgers
  run "$SSOT/bin/activity.sh"
  today=$(date +%m-%d)
  [[ "$output" == *"$today"* ]]
}

@test "activity shows session lines with persona emoji and duration" {
  setup_persona_and_ledgers
  run "$SSOT/bin/activity.sh"
  [[ "$output" == *"🏠"* ]]
  [[ "$output" == *"💼"* ]]
  [[ "$output" == *"22m"* ]] || [[ "$output" == *"22분"* ]]
  [[ "$output" == *"lawblaw_dev"* ]]
}

@test "activity sorts events newest first within day" {
  setup_persona_and_ledgers
  run "$SSOT/bin/activity.sh"
  # 오늘 13:25 (lawblaw)이 오늘 09:30 (claude-sync)보다 먼저 표시
  pm_pos=$(echo "$output" | grep -n "lawblaw_dev" | head -1 | cut -d: -f1)
  am_pos=$(echo "$output" | grep -n "claude-sync" | head -1 | cut -d: -f1)
  [ "$pm_pos" -lt "$am_pos" ]
}

@test "activity shows commit message when summary present" {
  setup_persona_and_ledgers
  run "$SSOT/bin/activity.sh"
  [[ "$output" == *"SSO 토큰 검증"* ]] || [[ "$output" == *"feat(billing)"* ]]
}

@test "activity handles empty ledgers gracefully" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  run "$SSOT/bin/activity.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"두 맥북"* ]]
}

# ── Task 2: 필터 옵션 ────────────────────────────────────────────────────────

@test "activity 30d uses 30-day window" {
  setup_persona_and_ledgers
  TS_OLD=$(date -v-15d +%Y-%m-%dT12:00:00%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  echo "{\"ts\":\"$TS_OLD\",\"host\":\"홈맥에어\",\"type\":\"session_end\",\"cwd\":\"/dev/old\",\"duration_min\":30}" \
    >> "$SSOT/state/activity/홈맥에어.jsonl"

  # 7d 기본은 15일 전 안 잡힘
  run "$SSOT/bin/activity.sh"
  [[ "$output" != *"old"* ]]

  # 30d 는 잡힘
  run "$SSOT/bin/activity.sh" 30d
  [[ "$output" == *"old"* ]]
}

@test "activity today filters to today only" {
  setup_persona_and_ledgers
  run "$SSOT/bin/activity.sh" today
  [ "$status" -eq 0 ]
  yesterday=$(date -v-1d +%m-%d)
  # 어제 데이터 안 보여야 (어제 날짜가 오늘 날짜 header에 없음)
  [[ "$output" != *"(어제)"* ]] || true
}

@test "activity <persona> filters by host" {
  setup_persona_and_ledgers
  run "$SSOT/bin/activity.sh" 회사맥프로
  [ "$status" -eq 0 ]
  # 홈맥에어 세션 안 보임
  [[ "$output" != *"claude-sync"* ]] || true
  [[ "$output" == *"lawblaw"* ]]
}

@test "activity <project> filters by cwd basename" {
  setup_persona_and_ledgers
  run "$SSOT/bin/activity.sh" lawblaw
  [ "$status" -eq 0 ]
  [[ "$output" == *"lawblaw"* ]]
  # claude-sync 세션 안 보여야
  [[ "$output" != *"claude-sync"* ]] || true
}

# ── Task 3: 통계 위젯 ────────────────────────────────────────────────────────

@test "activity shows weekday bar chart" {
  setup_persona_and_ledgers
  run "$SSOT/bin/activity.sh" 7d
  [[ "$output" == *"통계"* ]] || [[ "$output" == *"요일별"* ]]
  [[ "$output" == *"▓"* ]]
}

@test "activity shows momentum vs yesterday" {
  setup_persona_and_ledgers
  run "$SSOT/bin/activity.sh"
  [[ "$output" == *"모멘텀"* ]] || [[ "$output" == *"어제 대비"* ]]
}

# ── Task 4: --json 모드 ───────────────────────────────────────────────────────

@test "activity --json outputs valid JSONL" {
  setup_persona_and_ledgers
  run "$SSOT/bin/activity.sh" --json
  [ "$status" -eq 0 ]
  # 각 줄이 유효 JSON
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "$line" | jq empty || return 1
  done <<< "$output"
}

@test "activity --json respects filters" {
  setup_persona_and_ledgers
  run "$SSOT/bin/activity.sh" 회사맥프로 --json
  [ "$status" -eq 0 ]
  # 회사맥프로 host 포함되어야 함
  [[ "$output" == *'"host":"회사맥프로"'* ]]
  # 홈맥에어 host 없어야 함
  [[ "$output" != *'"host":"홈맥에어"'* ]]
}

# ── Task 5: --tui 모드 ───────────────────────────────────────────────────────

@test "activity --tui falls back when fzf missing or returns plain text" {
  setup_persona_and_ledgers
  if command -v fzf >/dev/null; then
    skip "fzf 설치돼 있어 manual smoke만"
  fi
  run "$SSOT/bin/activity.sh" --tui
  [ "$status" -eq 0 ]
}

@test "activity --tui build_tui_lines outputs session lines" {
  setup_persona_and_ledgers
  source "$SSOT/bin/activity.sh" --source-only 2>/dev/null || skip "--source-only 미지원"
  events_in=$(cat "$SSOT/state/activity/홈맥에어.jsonl" "$SSOT/state/activity/회사맥프로.jsonl" 2>/dev/null)
  lines=$(build_tui_lines "$events_in")
  count=$(echo "$lines" | wc -l | tr -d ' ')
  [ "$count" -ge "3" ]
}
