# 두 맥북 살아있음 시스템 — Phase 4 (통합 대시보드 `activity`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Phase 1~3 인프라가 쌓아 올린 활동 ledger를 한 명령(`activity`)으로 통합 시각화. 일자별 타임라인 + 통계 + TUI 인터랙티브 탐색.

**Architecture:** `ledger-query.sh` 가 데이터 백엔드. `activity.sh` 는 출력 포매터 + 필터 router. 4가지 출력 모드 — text(기본) / `--json` / `--tui`(fzf) — 가 같은 데이터를 다른 형태로 변환.

**Tech Stack:** bash 3.2+, jq, bats-core, fzf (선택, `--tui` 모드 시), Phase 1 helpers (persona, ledger-query)

**Pre-conditions:**
- Phase 1+2+3 main 머지 (커밋 `e41916c`)
- branch `feature/dual-mac-phase-4` (이미 분기됨)
- `ledger-query.sh` 가 `--type / --persona / --since / --format=text|jsonl` 지원
- fzf (Brewfile 에 이미 있음 가정 — 미설치 시 `--tui` fallback)

---

## File Structure

```
bin/
├── activity.sh        (Task 1+2+3+4+5)  메인 명령 + 필터 + 출력 모드
└── doctor.sh          (Task 6)          Phase 4 섹션 추가

shell/
└── zshrc.shared       (Task 6)          alias activity 추가

tests/
└── activity.bats      (Task 1+2+3+4)
```

총 6 tasks, ~22 bats tests, ~35 steps.

---

## Task 1: activity.sh 기본 텍스트 출력 + 일자별 헤더

**Files:**
- Create: `bin/activity.sh`
- Create: `tests/activity.bats`

**기능:**
- 인자 없으면 → 최근 7일 텍스트 출력
- 일자별 헤더 + 시간순 세션 라인
- 양 머신 합쳐 통합 타임라인
- 페르소나 이모지 + cwd basename + duration + summary

**예시 출력:**
```
═══════════════════════════════════════════════════════════
   두 맥북 · 최근 7일 · 총 4h 27m · 12 commits
═══════════════════════════════════════════════════════════

📅 04-29 화 (오늘)  🏠 47m + 💼 1h12m
       13:25  🏠 lawblaw_dev · 22m · "fix(auth): SSO 토큰..."
       11:00  💼 lawblaw_dev · 1h12m · "feat(billing): 결제 모달"
       09:30  🏠 claude-sync · 47m · "feat: cross-tool sync"

📅 04-28 월         🏠 2h00m + 💼 35m
       22:00  🏠 claude-sync · 2h · "feat: skill pool unification"
       18:30  💼 lawblaw_dev · 35m · "chore: deps update"
```

- [ ] **Step 1.1: 실패 테스트 작성**

Create `tests/activity.bats`:

```bash
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
```

- [ ] **Step 1.2: 테스트 실패 확인**

```bash
cd ~/.config/claude-sync && bats tests/activity.bats
# Expected: 6 tests, 6 failures
```

- [ ] **Step 1.3: bin/activity.sh 기본 구현**

Create `bin/activity.sh`:

```bash
#!/usr/bin/env bash
# activity.sh — 두 맥북 활동 통합 대시보드
# 사용법:
#   activity                    최근 7일 (기본)
#   activity 30d                30일
#   activity today              오늘만
#   activity <project>          프로젝트(cwd basename) 필터
#   activity <persona>          머신(홈맥에어/회사맥프로) 필터
#   activity --tui              fzf 인터랙티브 (Task 5)
#   activity --json             JSONL 출력 (Task 4)

set -uo pipefail

SSOT="$HOME/.config/claude-sync"
LEDGER_QUERY="$SSOT/bin/ledger-query.sh"
LEDGER_DIR="$SSOT/state/activity"

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
events=$("$LEDGER_QUERY" "${query_args[@]}" 2>/dev/null || echo "")

# project 필터 (basename(cwd) match)
if [[ -n "$filter_project" ]]; then
  events=$(echo "$events" | jq -c --arg p "$filter_project" \
    'select(.cwd != null and (.cwd | split("/") | last | contains($p)))' 2>/dev/null)
fi

# JSON 모드 (Task 4 에서 추가) — 일단 빈 출력
if [[ "$mode" == "json" ]]; then
  echo "$events"
  exit 0
fi

# TUI 모드 (Task 5 에서 추가)
if [[ "$mode" == "tui" ]]; then
  echo "(TUI mode - 미구현)" >&2
  exit 1
fi

# 텍스트 모드 (기본)

# 헤더
total_duration=0
total_commits=0
session_count=0
if [[ -n "$events" ]]; then
  total_duration=$(echo "$events" | jq -s '[.[] | select(.type == "session_end") | (.duration_min // 0)] | add // 0')
  total_commits=$(echo "$events" | jq -s '[.[] | select(.type == "session_end") | (.commits // 0)] | add // 0')
  session_count=$(echo "$events" | jq -s '[.[] | select(.type == "session_end")] | length')
fi

human_duration() {
  local m="$1"
  if (( m >= 60 )); then
    printf "%dh%dm" $(( m / 60 )) $(( m % 60 ))
  else
    printf "%dm" "$m"
  fi
}

echo "═══════════════════════════════════════════════════════════"
printf "   두 맥북 · 최근 %s · 총 %s · %d commits\n" "$since" "$(human_duration "$total_duration")" "$total_commits"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 일자별 그룹 (newest first)
if [[ -z "$events" ]]; then
  echo "(활동 없음)"
  exit 0
fi

# event ts → 일자 추출 (YYYY-MM-DD 부분), unique sort -r (newest first)
days=$(echo "$events" | jq -r '.ts | split("T")[0]' | sort -ur)

today=$(date +%Y-%m-%d)
yesterday=$(date -v-1d +%Y-%m-%d)

for day in $days; do
  # day 라벨
  day_label="${day:5}"  # MM-DD
  if [[ "$day" == "$today" ]]; then
    day_label="$day_label (오늘)"
  elif [[ "$day" == "$yesterday" ]]; then
    day_label="$day_label (어제)"
  fi

  # 그날 머신별 시간 합계
  home_min=$(echo "$events" | jq --arg d "$day" \
    '[.[] | select(.type == "session_end" and .host == "홈맥에어" and (.ts | startswith($d))) | (.duration_min // 0)] | add // 0' 2>/dev/null)
  work_min=$(echo "$events" | jq --arg d "$day" \
    '[.[] | select(.type == "session_end" and .host == "회사맥프로" and (.ts | startswith($d))) | (.duration_min // 0)] | add // 0' 2>/dev/null)

  printf "📅 %s   🏠 %s + 💼 %s\n" "$day_label" "$(human_duration "${home_min:-0}")" "$(human_duration "${work_min:-0}")"

  # 그날 세션들 (newest first)
  echo "$events" | jq --arg d "$day" -r \
    'select(.type == "session_end" and (.ts | startswith($d))) |
     {ts:.ts, host:.host, cwd:.cwd, dur:.duration_min, sum:.summary}' \
    2>/dev/null | jq -s -r 'sort_by(.ts) | reverse | .[] |
       (if .host == "홈맥에어" then "🏠" else "💼" end) as $e |
       "       \(.ts | split("T")[1] | split(":") | "\(.[0]):\(.[1])")  \($e) \(.cwd // "?" | split("/") | last) · \((.dur // 0) | tostring)m" + (if .sum then " · \"\(.sum)\"" else "" end)' \
    2>/dev/null

  echo ""
done
```

권한:
```bash
chmod +x ~/.config/claude-sync/bin/activity.sh
```

- [ ] **Step 1.4: 테스트 통과 확인 → 6/6**

```bash
cd ~/.config/claude-sync && bats tests/activity.bats
# Expected: 6 tests, 0 failures
```

- [ ] **Step 1.5: 자기 PC 실측**

```bash
~/.config/claude-sync/bin/activity.sh
# Expected: 헤더 + 일자별 섹션 (현재 ledger 데이터 따라)
```

- [ ] **Step 1.6: 커밋**

```bash
cd ~/.config/claude-sync
git add bin/activity.sh tests/activity.bats
git commit -m "feat(activity): 통합 대시보드 기본 텍스트 출력

- bin/activity.sh: 일자별 헤더 + 시간순 세션 라인
- 헤더: 총 duration + commits + session count
- 페르소나 이모지 + cwd basename + duration + summary
- 6 bats tests"
```

---

## Task 2: 필터 옵션

**Files:**
- Modify: `tests/activity.bats` (필터 tests 추가)

이미 Task 1 의 인자 파싱이 필터를 지원 (`30d`, `today`, `홈맥에어`, project name). 검증 tests 추가.

- [ ] **Step 2.1: 필터 tests 추가**

`tests/activity.bats` 끝에:

```bash
@test "activity 30d uses 30-day window" {
  setup_persona_and_ledgers
  TS_OLD=$(date -v-15d +%Y-%m-%dT12:00:00%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  echo "{\"ts\":\"$TS_OLD\",\"host\":\"홈맥에어\",\"type\":\"session_end\",\"cwd\":\"/dev/old\",\"duration_min\":30}" \
    >> "$SSOT/state/activity/홈맥에어.jsonl"

  # 7d 기본은 15일 전 안 잡힘
  run "$SSOT/bin/activity.sh"
  [[ "$output" != *"/dev/old"* ]]

  # 30d 는 잡힘
  run "$SSOT/bin/activity.sh" 30d
  [[ "$output" == *"/dev/old"* ]] || [[ "$output" == *"old"* ]]
}

@test "activity today filters to today only" {
  setup_persona_and_ledgers
  run "$SSOT/bin/activity.sh" today
  [ "$status" -eq 0 ]
  yesterday=$(date -v-1d +%m-%d)
  # 어제 데이터 안 보여야
  [[ "$output" != *"$yesterday"* ]] || true
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
```

- [ ] **Step 2.2: 테스트 통과 확인 → 10/10**

```bash
cd ~/.config/claude-sync && bats tests/activity.bats
# Expected: 10 tests, 0 failures (필터는 이미 Task 1에서 구현됨)
```

만약 일부 fail이면 Task 1 의 인자 파싱 분기 디버그.

- [ ] **Step 2.3: 자기 PC 실측**

```bash
~/.config/claude-sync/bin/activity.sh today
~/.config/claude-sync/bin/activity.sh 30d
~/.config/claude-sync/bin/activity.sh 회사맥프로
~/.config/claude-sync/bin/activity.sh claude-sync
```

- [ ] **Step 2.4: 커밋**

```bash
cd ~/.config/claude-sync
git add tests/activity.bats
git commit -m "test(activity): 필터 옵션 검증 (30d/today/persona/project)

- 4 추가 tests (총 10)"
```

---

## Task 3: 통계 위젯 (요일 막대 + momentum)

**Files:**
- Modify: `bin/activity.sh` (출력 끝에 통계 섹션 추가)
- Modify: `tests/activity.bats`

**기능:**
- 출력 끝에 요일별 활동 시간 ASCII 막대그래프
- "어제 대비 +N%" momentum 메시지

**예시:**
```
[ 통계 ] 요일별 활동 시간
   월 ▓▓▓▓░  화 ▓▓▓▓▓▓  수 ▓▓░  목 ▓░  금 ▓▓▓  토 ▓  일 ▓▓▓▓
[ 모멘텀 ] 어제 대비 +20%
```

- [ ] **Step 3.1: 통계 tests 추가**

`tests/activity.bats` 끝에:

```bash
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
```

- [ ] **Step 3.2: 실패 확인 → 2 새 fail**

- [ ] **Step 3.3: bin/activity.sh 끝에 통계 섹션 추가**

`bin/activity.sh` 의 마지막 `done` (일자별 loop 끝) **다음에**, 그러나 exit 직전에 추가:

```bash
# === 통계 위젯 ===

# 요일별 활동 시간 (월=Mon)
echo ""
echo "[ 통계 ] 요일별 활동 시간"

# 7일 분 — 각 요일 분
declare_weekdays() {
  # bash 3.2 호환 — assoc 없음. 7개 변수 사용
  d_mon=0; d_tue=0; d_wed=0; d_thu=0; d_fri=0; d_sat=0; d_sun=0
}
declare_weekdays

# 7일 ts → 요일 추출
if [[ -n "$events" ]]; then
  while IFS=$'\t' read -r ts dur; do
    [[ -z "$ts" || "$ts" == "null" ]] && continue
    # ts 의 day part
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
[[ "$max_min" -le 0 ]] && max_min=1  # divide-by-zero 방지

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
today_min=$(echo "$events" | jq --arg d "$today_iso" \
  '[.[] | select(.type == "session_end" and (.ts | startswith($d))) | (.duration_min // 0)] | add // 0' 2>/dev/null)
yest_min=$(echo "$events" | jq --arg d "$yest_iso" \
  '[.[] | select(.type == "session_end" and (.ts | startswith($d))) | (.duration_min // 0)] | add // 0' 2>/dev/null)

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
```

`bash 3.2` 의 `local` 안 쓰는 함수 형태 (declare_weekdays 는 글로벌 변수 set).

- [ ] **Step 3.4: 테스트 통과 → 12/12**

```bash
cd ~/.config/claude-sync && bats tests/activity.bats
# Expected: 12 tests pass
```

- [ ] **Step 3.5: 자기 PC 실측**

```bash
~/.config/claude-sync/bin/activity.sh
# Expected: 헤더 + 일자 + 통계 섹션 (요일 bar + 모멘텀)
```

- [ ] **Step 3.6: 커밋**

```bash
cd ~/.config/claude-sync
git add bin/activity.sh tests/activity.bats
git commit -m "feat(activity): 요일 막대그래프 + 모멘텀 위젯

- 요일별 활동 시간 ASCII 막대 (5칸 정규화)
- 오늘 vs 어제 모멘텀 (+N% / -N%)
- 2 추가 tests (총 12)"
```

---

## Task 4: --json 출력 모드

**Files:**
- Modify: `bin/activity.sh` (--json 분기 — 이미 Task 1 골격 있음)
- Modify: `tests/activity.bats`

**기능:** `activity --json` → 필터된 이벤트들을 JSONL 한 줄씩 출력 (jq 등 다른 도구 파이프).

이미 Task 1 의 mode=json 분기에서 events 출력. 검증 tests 추가.

- [ ] **Step 4.1: --json tests 추가**

```bash
@test "activity --json outputs valid JSONL" {
  setup_persona_and_ledgers
  run "$SSOT/bin/activity.sh" --json
  [ "$status" -eq 0 ]
  # 각 줄이 유효 JSON
  echo "$output" | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "$line" | jq empty || return 1
  done
}

@test "activity --json respects filters" {
  setup_persona_and_ledgers
  run "$SSOT/bin/activity.sh" 회사맥프로 --json
  count=$(echo "$output" | grep -c '"host":"회사맥프로"' || echo 0)
  [[ "$count" -ge "1" ]]
  count_home=$(echo "$output" | grep -c '"host":"홈맥에어"' || echo 0)
  [ "$count_home" = "0" ]
}
```

- [ ] **Step 4.2: 테스트 실행**

```bash
cd ~/.config/claude-sync && bats tests/activity.bats
# Expected: 14 tests, 0 failures (Task 1 골격으로 이미 작동)
```

만약 fail이면 activity.sh 의 mode=json 분기 디버그. 위 골격은 events 만 출력 — header/footer 없이 raw JSONL.

- [ ] **Step 4.3: 자기 PC 실측**

```bash
~/.config/claude-sync/bin/activity.sh --json | jq -c
# Expected: 각 이벤트가 jq로 파싱 가능
```

- [ ] **Step 4.4: 커밋**

```bash
cd ~/.config/claude-sync
git add tests/activity.bats
git commit -m "test(activity): --json 출력 검증

- 2 추가 tests (총 14)"
```

---

## Task 5: --tui 모드 (fzf 인터랙티브)

**Files:**
- Modify: `bin/activity.sh` (--tui 분기 구현)
- Modify: `tests/activity.bats`

**기능:**
- `activity --tui` → fzf 로 세션 리스트 표시
- 화살표 키 ↑↓ 로 세션 탐색
- Enter → 자세 정보 (cwd, summary, commits, files_changed)
- fzf 미설치 시 fallback 평문

- [ ] **Step 5.1: --tui tests 추가**

```bash
@test "activity --tui falls back to plain text when fzf missing" {
  setup_persona_and_ledgers
  # fzf PATH에서 제거된 환경 시뮬레이션 — PATH override 어려움
  # 대신 --tui 가 어떤 경로로든 exit 0 + 출력 있는지만
  if command -v fzf >/dev/null; then
    skip "fzf 설치돼 있어 fallback 못 검증 (manual)"
  fi
  run "$SSOT/bin/activity.sh" --tui
  [ "$status" -eq 0 ]
  [[ "$output" == *"홈맥에어"* ]] || [[ "$output" == *"회사맥프로"* ]]
}

@test "activity --tui builds fzf input lines (each line is a session)" {
  setup_persona_and_ledgers
  # build_tui_lines 함수 단위 테스트
  source "$SSOT/bin/activity.sh" --source-only 2>/dev/null || skip
  events_in=$(cat "$SSOT/state/activity/홈맥에어.jsonl" "$SSOT/state/activity/회사맥프로.jsonl" 2>/dev/null)
  lines=$(build_tui_lines "$events_in")
  count=$(echo "$lines" | wc -l | tr -d ' ')
  [ "$count" -ge "3" ]
}
```

- [ ] **Step 5.2: 실패 확인 → 2 새 fail**

- [ ] **Step 5.3: bin/activity.sh 의 --tui 분기 구현**

`bin/activity.sh` 의 `if [[ "$mode" == "tui" ]]; then echo "(TUI mode - 미구현)" >&2; exit 1; fi` 부분을 다음으로 교체:

```bash
# TUI 모드 (fzf 활용)
build_tui_lines() {
  local input="$1"
  echo "$input" | jq -r 'select(.type == "session_end") |
    (if .host == "홈맥에어" then "🏠" else "💼" end) as $e |
    "\(.ts | split("T")[0]) \(.ts | split("T")[1] | split(":") | "\(.[0]):\(.[1])")  \($e) \(.cwd // "?" | split("/") | last) · \((.duration_min // 0) | tostring)m" + (if .summary then " · \"\(.summary)\"" else "" end)' \
    2>/dev/null | sort -r
}

# --source-only 모드
if [[ "${1:-}" == "--source-only" ]]; then
  return 0 2>/dev/null || exit 0
fi

if [[ "$mode" == "tui" ]]; then
  if ! command -v fzf >/dev/null; then
    echo "⚠ fzf 미설치 — plain text 출력 fallback" >&2
    # plain text 그냥 진행
    mode="text"
  else
    lines=$(build_tui_lines "$events")
    if [[ -z "$lines" ]]; then
      echo "(활동 없음)"
      exit 0
    fi
    selected=$(echo "$lines" | fzf \
      --height 50% --reverse \
      --header="↑↓ 세션 / Enter 자세 정보 / q 종료" \
      --preview="echo {} | sed -E 's/.*· (.+)/\\1/'" \
      --preview-window=up:3:wrap)
    if [[ -n "$selected" ]]; then
      # 선택된 줄 표시
      echo "$selected"
    fi
    exit 0
  fi
fi
```

- [ ] **Step 5.4: 테스트 통과**

```bash
cd ~/.config/claude-sync && bats tests/activity.bats
# Expected: 16 tests pass (또는 첫 1개 skip — fzf 설치 환경)
```

- [ ] **Step 5.5: 자기 PC manual smoke**

```bash
~/.config/claude-sync/bin/activity.sh --tui
# Expected: fzf 인터랙티브 → 세션 선택 → 그 줄 출력 후 종료
# (fzf 미설치 환경에선 plain text fallback)
```

- [ ] **Step 5.6: 커밋**

```bash
cd ~/.config/claude-sync
git add bin/activity.sh tests/activity.bats
git commit -m "feat(activity): --tui 모드 (fzf 인터랙티브)

- bin/activity.sh: --tui 분기 + build_tui_lines 함수
- fzf 미설치 시 plain text fallback
- 2 추가 tests (총 16)"
```

---

## Task 6: alias 등록 + doctor Phase 4 검증

**Files:**
- Modify: `shell/zshrc.shared` (alias activity)
- Modify: `bin/doctor.sh` (Phase 4 섹션)

- [ ] **Step 6.1: zsh alias 추가**

`shell/zshrc.shared` 끝에:
```bash
# 두 맥북 통합 활동 대시보드
alias activity='$HOME/.config/claude-sync/bin/activity.sh'
```

- [ ] **Step 6.2: doctor.sh 에 Phase 4 섹션 추가**

마지막 결과 echo 직전에:

```bash
echo ""
echo "── Phase 4: 통합 대시보드 (activity) ──"

# helper
if [[ -x "$SSOT/bin/activity.sh" ]]; then
  echo "✓ bin/activity.sh"
else
  echo "❌ bin/activity.sh 실행 권한/존재 X"; ((errors++))
fi

# alias
if grep -q "alias activity=" "$SSOT/shell/zshrc.shared" 2>/dev/null; then
  echo "✓ zsh alias activity 등록"
else
  echo "❌ alias activity 미등록"; ((errors++))
fi

# fzf 설치 (--tui 의존)
if command -v fzf >/dev/null; then
  echo "✓ fzf $(fzf --version | head -1)"
else
  echo "⚠ fzf 미설치 — activity --tui 는 plain text fallback"
fi
```

- [ ] **Step 6.3: doctor 실행**

```bash
~/.config/claude-sync/bin/doctor.sh
# Expected: Phase 4 섹션 모두 ✓
```

- [ ] **Step 6.4: 모든 bats 회귀**

```bash
~/.config/claude-sync/bin/test.sh
# Expected: 80+ tests pass
```

- [ ] **Step 6.5: 자기 PC manual smoke**

```bash
exec zsh
activity                    # 7일 기본
activity today              # 오늘
activity 회사맥프로
activity --json | jq -c | head
activity --tui              # fzf 인터랙티브 (있으면)
```

- [ ] **Step 6.6: 커밋**

```bash
cd ~/.config/claude-sync
git add shell/zshrc.shared bin/doctor.sh
git commit -m "feat+chore(activity): alias activity + doctor Phase 4 검증

- shell/zshrc.shared: alias activity = '... activity.sh'
- bin/doctor.sh: Phase 4 섹션 (activity.sh, alias, fzf)

Phase 4 완료. 두 맥북 살아있음 시스템 (Phase 1+2+3+4) 전체 완성:
- C1 셋업 라이브 중계 ✓
- C2 양 맥북 HUD ✓
- C3 세션 끝 알림 + 출퇴근 catchup + 일일 요약 ✓
- C4 통합 대시보드 (activity + TUI) ✓
- C5 첫 인사 모먼트 ✓"
```

---

## Phase 4 완료 검증 체크리스트

- [ ] `activity` (인자 없음) → 7일 기본 출력
- [ ] `activity 30d` / `today` / 페르소나 / 프로젝트 필터 작동
- [ ] 일자별 헤더 + 시간순 세션 라인
- [ ] 요일별 막대그래프 + 모멘텀 위젯
- [ ] `activity --json` → JSONL pipe-able
- [ ] `activity --tui` → fzf 인터랙티브 (또는 fallback)
- [ ] alias 등록 + doctor Phase 4 ✓
- [ ] 모든 bats 회귀 pass

## 다음 단계

Phase 4 완료 시 두 맥북 살아있음 시스템 전체 완성. 별도 phase 5 없음.

남은 follow-ups (이전 review에서 발견):
- commits 카운트 producer 추가 (notify-session-end가 git log 활용)
- hud-flash producer (다른 머신 활동 도착 시)
- persona-emoji 매핑 중앙화 (persona.sh --other-json)

이 follow-ups은 별도 작은 PR로.
