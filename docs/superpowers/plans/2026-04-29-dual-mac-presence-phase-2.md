# 두 맥북 살아있음 시스템 — Phase 2 (HUD + Stop hook + Catchup) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Phase 1 ledger 인프라 위에 양 맥북이 서로의 존재를 인지하는 일상 와우 모먼트(HUD / 세션끝알림 / 출퇴근 catchup / 일일요약)를 구현한다.

**Architecture:** `ledger-query.sh` 가 모든 위젯의 단일 데이터 source. HUD는 5초 캐시로 매 prompt 부담 최소화. Stop hook이 의미 있는 세션(≥3분 또는 ≥1commit)만 push. 4시간+ 휴면 후 첫 prompt 시 catchup 표시. 매일 아침 08:00 launchd가 어제 활동 통합 요약 push.

**Tech Stack:** bash 3.2+, jq, bats-core (testing), zsh (chpwd/precmd hooks), launchd, Telegram bot API, Phase 1 helpers (persona/ledger-append/ledger-query/notify-activity/sync --immediate)

**Pre-conditions:**
- Phase 1 완료 (commit `648e5d6` on main): persona/ledger/notify-activity 인프라 작동
- `.machine.json` 자기 머신에 존재 (`bin/persona.sh --init` 완료 상태)
- bats-core 설치
- branch `feature/dual-mac-phase-2` (이미 분기됨)

---

## File Structure

신규/수정 파일 매핑:

```
bin/
├── hud-machines.sh         (Task 1+2)  HUD 라인/상세 출력 + 5초 캐시
├── summarize-session.sh    (Task 5)    cwd + commits + duration → 헤드라인
├── notify-session-end.sh   (Task 6)    Stop hook 트리거 (≥3분/1commit)
├── hud-catchup.sh          (Task 8)    4시간+ 휴면 후 어제 활동 표시
├── daily-digest.sh         (Task 9)    어제 활동 통합 → Telegram
└── doctor.sh               (Task 10)   Phase 2 섹션 추가

claude/
├── hud/omc-hud.mjs         (Task 4)    Claude statusline 새 segment
└── settings.shared.json    (Task 7)    Stop hook 에 notify-session-end 추가

shell/
└── zshrc.shared            (Task 3, 8) RPROMPT + alias hudm + precmd hook

launchd/
└── com.denny.claude-sync-digest.plist  (Task 9)  매일 08:00 daily-digest 트리거

state/
├── hud-cache/              (Task 1)    {persona}.txt 5초 TTL 캐시
├── hud-flash.txt           (Task 4)    새 활동 도착 마커 (5초 ✨반짝)
└── last-prompt-ts.txt      (Task 8)    catchup 1회 마킹

tests/
├── hud-machines.bats       (Task 1+2)
├── summarize-session.bats  (Task 5)
├── notify-session-end.bats (Task 6)
├── hud-catchup.bats        (Task 8)
└── daily-digest.bats       (Task 9)
```

총 9 tasks, ~50 bats tests, ~55 steps.

---

## Task 1: HUD 라인 출력 + 5초 캐시

**Files:**
- Create: `bin/hud-machines.sh`
- Create: `tests/hud-machines.bats`
- Create: `state/hud-cache/.gitkeep`

**기능:**
- `hud-machines.sh --format=line` → `🏠 홈맥에어 ●  💼 회사맥프로 ✨방금` 같은 단일 라인
- 5초 캐시 (`state/hud-cache/{persona}.txt`) — 매 prompt 부담 최소화
- 상태별 시각:
  - 자기 머신: `🏠 홈맥에어 ●` (늘 표시, 활동 시점 무관)
  - 상대 활동 중 (<2분): `💼 회사맥프로 ✨방금`
  - 상대 최근 (<30분): `💼 회사맥프로 ⚡5분`
  - 상대 잠잠 (<24h): `💼 회사맥프로 🕐2h`
  - 상대 어제 (<7일): `💼 회사맥프로 💤어제`
  - 상대 조용함 (≥7일): `💼 회사맥프로 🌑`

- [ ] **Step 1.1: 실패 테스트 작성**

Create `tests/hud-machines.bats`:

```bash
# tests/hud-machines.bats
load test_helper

setup_persona_and_ledgers() {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity" "$SSOT/state/hud-cache"

  # 상대 머신 (회사맥프로) — 5분 전 활동
  TS_5MIN=$(date -v-5M +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  cat > "$SSOT/state/activity/회사맥프로.jsonl" <<EOF
{"ts":"$TS_5MIN","host":"회사맥프로","type":"session_end","cwd":"/dev/lawblaw","duration_min":22}
EOF
  export TS_5MIN
}

@test "hud-machines --format=line includes both persona names" {
  setup_persona_and_ledgers
  run "$SSOT/bin/hud-machines.sh" --format=line
  [ "$status" -eq 0 ]
  [[ "$output" == *"홈맥에어"* ]]
  [[ "$output" == *"회사맥프로"* ]]
}

@test "hud-machines self machine has solid dot ●" {
  setup_persona_and_ledgers
  run "$SSOT/bin/hud-machines.sh" --format=line
  [[ "$output" == *"🏠 홈맥에어 ●"* ]]
}

@test "hud-machines other machine 5min ago shows ⚡" {
  setup_persona_and_ledgers
  run "$SSOT/bin/hud-machines.sh" --format=line
  [[ "$output" == *"⚡"* ]]
  [[ "$output" == *"5"* ]]
}

@test "hud-machines other machine <2min ago shows ✨방금" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  TS_NOW=$(date -v-1M +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  echo "{\"ts\":\"$TS_NOW\",\"host\":\"회사맥프로\",\"type\":\"wake\"}" > "$SSOT/state/activity/회사맥프로.jsonl"
  run "$SSOT/bin/hud-machines.sh" --format=line
  [[ "$output" == *"✨방금"* ]]
}

@test "hud-machines other machine ≥7d shows 🌑" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  TS_OLD=$(date -v-10d +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  echo "{\"ts\":\"$TS_OLD\",\"host\":\"회사맥프로\",\"type\":\"wake\"}" > "$SSOT/state/activity/회사맥프로.jsonl"
  run "$SSOT/bin/hud-machines.sh" --format=line
  [[ "$output" == *"🌑"* ]]
}

@test "hud-machines other machine never seen omits other persona section gracefully" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  # 회사맥프로 ledger 없음
  run "$SSOT/bin/hud-machines.sh" --format=line
  [ "$status" -eq 0 ]
  [[ "$output" == *"홈맥에어"* ]]
  # "회사맥프로" 가 없거나 🌑 (한 번도 본 적 없음 표시) — 스크립트 결정에 따름
}

@test "hud-machines uses cache within 5s TTL" {
  setup_persona_and_ledgers
  run "$SSOT/bin/hud-machines.sh" --format=line
  cache_file="$SSOT/state/hud-cache/홈맥에어.txt"
  [ -f "$cache_file" ]
  first_output="$output"

  # 다시 호출 → 캐시 사용 (출력 동일)
  run "$SSOT/bin/hud-machines.sh" --format=line
  [ "$output" = "$first_output" ]
}

@test "hud-machines bypasses cache with --no-cache" {
  setup_persona_and_ledgers
  "$SSOT/bin/hud-machines.sh" --format=line >/dev/null
  cache_file="$SSOT/state/hud-cache/홈맥에어.txt"
  cache_mtime_before=$(stat -f %m "$cache_file")

  sleep 1
  run "$SSOT/bin/hud-machines.sh" --format=line --no-cache
  [ "$status" -eq 0 ]
  cache_mtime_after=$(stat -f %m "$cache_file")
  # --no-cache 가 캐시 새로 씀 (mtime 갱신)
  [ "$cache_mtime_after" -gt "$cache_mtime_before" ]
}
```

- [ ] **Step 1.2: 테스트 실패 확인**

```bash
cd ~/.config/claude-sync && bats tests/hud-machines.bats
# Expected: 8 tests, 8 failures (script 없음)
```

- [ ] **Step 1.3: hud-machines.sh 구현**

Create `bin/hud-machines.sh`:

```bash
#!/usr/bin/env bash
# hud-machines.sh — 두 맥북 상태를 단일 라인으로 표시
# 사용법:
#   hud-machines.sh --format=line       단일 라인 (자기 + 상대)
#   hud-machines.sh --format=detail     상세 정보 (Task 2)
#   hud-machines.sh --no-cache          캐시 무시
#
# 5초 캐시: state/hud-cache/{persona}.txt

set -uo pipefail

SSOT="$HOME/.config/claude-sync"
PERSONA_BIN="$SSOT/bin/persona.sh"
LEDGER_DIR="$SSOT/state/activity"
CACHE_DIR="$SSOT/state/hud-cache"
CACHE_TTL=5  # seconds

format="line"
use_cache=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format=*) format="${1#--format=}"; shift ;;
    --no-cache) use_cache=0; shift ;;
    *) echo "사용법: hud-machines.sh [--format=line|detail] [--no-cache]" >&2; exit 1 ;;
  esac
done

# 자기 페르소나 + 상대 페르소나 조회
self_json=$("$PERSONA_BIN" --json 2>/dev/null) || { echo "❌ persona 조회 실패" >&2; exit 1; }
self=$(echo "$self_json" | jq -r '.persona')
self_emoji=$(echo "$self_json" | jq -r '.emoji')
other=$("$PERSONA_BIN" --other 2>/dev/null) || other=""

# 상대 이모지 (자기와 반대)
if [[ "$self" == "홈맥에어" ]]; then
  other_emoji="💼"
else
  other_emoji="🏠"
fi

mkdir -p "$CACHE_DIR"
cache_file="$CACHE_DIR/$self.txt"

# 캐시 확인 (5초 이내면 재사용)
if (( use_cache )) && [[ -f "$cache_file" ]]; then
  cache_age=$(( $(date +%s) - $(stat -f %m "$cache_file") ))
  if (( cache_age < CACHE_TTL )); then
    cat "$cache_file"
    exit 0
  fi
fi

# 상대 머신의 마지막 이벤트 ts 조회
other_last_ts=""
if [[ -f "$LEDGER_DIR/$other.jsonl" ]]; then
  other_last_ts=$(jq -r '.ts' "$LEDGER_DIR/$other.jsonl" 2>/dev/null | sort | tail -1)
fi

# 상대 상태 라벨 결정 (✨방금/⚡Nm/🕐Nh/💤어제/🌑)
other_label=""
if [[ -n "$other_last_ts" && "$other_last_ts" != "null" ]]; then
  # ts → unix epoch (BSD date, ISO8601 with timezone)
  # 형식 예: 2026-04-29T13:25:00+09:00 → 분리 후 BSD date 파싱
  ts_no_tz="${other_last_ts%%[+-]*}"
  tz_part="${other_last_ts:${#ts_no_tz}}"
  # tz_part 예 "+09:00" → "+0900" 으로 변환 (BSD date 호환)
  tz_compact="${tz_part//:/}"
  full_ts_for_parse="${ts_no_tz}${tz_compact}"
  other_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$full_ts_for_parse" +%s 2>/dev/null || echo 0)
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

# 라인 출력
if [[ "$format" == "line" ]]; then
  if [[ -n "$other_label" ]]; then
    out="$self_emoji $self ●  $other_emoji $other $other_label"
  else
    out="$self_emoji $self ●  $other_emoji $other 🌑"
  fi
  echo "$out" | tee "$cache_file"
elif [[ "$format" == "detail" ]]; then
  # detail 출력은 Task 2 에서 구현
  echo "(detail format은 Task 2 에서 추가)" >&2
  exit 1
else
  echo "알 수 없는 format: $format" >&2
  exit 1
fi
```

권한:
```bash
chmod +x ~/.config/claude-sync/bin/hud-machines.sh
```

- [ ] **Step 1.4: 테스트 통과 확인**

```bash
cd ~/.config/claude-sync && bats tests/hud-machines.bats
# Expected: 8 tests, 0 failures
```

- [ ] **Step 1.5: state/hud-cache 디렉터리 + .gitkeep**

```bash
mkdir -p ~/.config/claude-sync/state/hud-cache
touch ~/.config/claude-sync/state/hud-cache/.gitkeep
```

또 `.gitignore` 끝에 캐시 파일 자체는 ignore:
```
# HUD 캐시 (머신별 5s TTL)
state/hud-cache/*.txt
```

- [ ] **Step 1.6: 자기 PC 실측**

```bash
~/.config/claude-sync/bin/hud-machines.sh --format=line
# Expected: 🏠 홈맥에어 ●  💼 회사맥프로 [상태]  (또는 🌑 if 상대 ledger 비어있음)
```

- [ ] **Step 1.7: 커밋**

```bash
cd ~/.config/claude-sync
git add bin/hud-machines.sh tests/hud-machines.bats state/hud-cache/.gitkeep .gitignore
git commit -m "feat(hud): hud-machines.sh line format + 5초 캐시

- bin/hud-machines.sh --format=line: 자기 ● + 상대 ✨방금/⚡Nm/🕐Nh/💤/🌑
- state/hud-cache/{persona}.txt 5초 TTL
- 8 bats tests"
```

---

## Task 2: HUD detail 출력 + `hudm` alias

**Files:**
- Modify: `bin/hud-machines.sh` (`--format=detail` 분기 추가)
- Modify: `tests/hud-machines.bats` (detail tests 추가)
- Modify: `shell/zshrc.shared` (alias `hudm` 추가)

**기능:**
- `hud-machines.sh --format=detail` → 자세 정보 출력 (마지막 세션, 오늘 commits 카운트 등)
- `hudm` alias (zsh) — `hud-machines.sh --format=detail` 호출

**예시 출력:**
```
🏠 홈맥에어 ● 활동 중
   - 마지막: claude session in /dev/claude-sync (방금)
   - 오늘 commits: 7개

💼 회사맥프로 ⚡ 5분 전
   - 마지막: claude session in /dev/lawblaw_dev (5분, 22m, 3 commits)
   - "fix(auth): SSO 토큰 검증"
   - 오늘 commits: 3개
```

- [ ] **Step 2.1: 실패 테스트 추가**

`tests/hud-machines.bats` 끝에 추가:

```bash
@test "hud-machines --format=detail shows last session info" {
  setup_persona_and_ledgers
  run "$SSOT/bin/hud-machines.sh" --format=detail
  [ "$status" -eq 0 ]
  [[ "$output" == *"홈맥에어"* ]]
  [[ "$output" == *"회사맥프로"* ]]
  # 마지막 cwd 표시
  [[ "$output" == *"lawblaw"* ]]
}

@test "hud-machines --format=detail counts today commits" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  TS_NOW=$(date +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  cat > "$SSOT/state/activity/홈맥에어.jsonl" <<EOF
{"ts":"$TS_NOW","host":"홈맥에어","type":"commit","sha":"abc1"}
{"ts":"$TS_NOW","host":"홈맥에어","type":"commit","sha":"abc2"}
{"ts":"$TS_NOW","host":"홈맥에어","type":"commit","sha":"abc3"}
EOF
  run "$SSOT/bin/hud-machines.sh" --format=detail
  [[ "$output" == *"오늘 commits: 3"* ]]
}

@test "hud-machines --format=detail handles empty other ledger" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  run "$SSOT/bin/hud-machines.sh" --format=detail
  [ "$status" -eq 0 ]
  [[ "$output" == *"홈맥에어"* ]]
}
```

- [ ] **Step 2.2: 테스트 실패 확인**

```bash
cd ~/.config/claude-sync && bats tests/hud-machines.bats
# Expected: 11 tests, 3 새 failures (detail format 미구현)
```

- [ ] **Step 2.3: hud-machines.sh detail 분기 구현**

`bin/hud-machines.sh` 의 `elif [[ "$format" == "detail" ]]; then` 블록을 다음으로 교체:

```bash
elif [[ "$format" == "detail" ]]; then
  # 자기 머신 자세 정보
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

  # 상대 머신 자세 정보
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
fi
```

- [ ] **Step 2.4: 테스트 통과 확인**

```bash
cd ~/.config/claude-sync && bats tests/hud-machines.bats
# Expected: 11 tests, 0 failures
```

- [ ] **Step 2.5: zsh alias 추가**

`shell/zshrc.shared` 의 alias 섹션 (있다면)에 다음 추가. 없으면 파일 끝에:

```bash
# HUD: 두 맥북 상태 한눈
alias hudm='$HOME/.config/claude-sync/bin/hud-machines.sh --format=detail'
```

- [ ] **Step 2.6: 자기 PC 실측**

```bash
exec zsh  # alias 활성화
hudm
# Expected: 자기 + 상대 자세 정보 출력
```

- [ ] **Step 2.7: 커밋**

```bash
cd ~/.config/claude-sync
git add bin/hud-machines.sh tests/hud-machines.bats shell/zshrc.shared
git commit -m "feat(hud): hud-machines.sh detail format + hudm alias

- --format=detail: 마지막 세션 cwd/duration/message + 오늘 commits
- alias hudm = '... --format=detail'
- 3 추가 tests (총 11)"
```

---

## Task 3: zsh RPROMPT segment

**Files:**
- Modify: `shell/zshrc.shared` (RPROMPT segment 추가)

**기능:**
- 매 prompt 오른쪽 끝에 `hud-machines.sh --format=line` 출력
- 5초 캐시로 매 keystroke 부담 없음
- silent fail (스크립트 없거나 ledger 없어도 prompt 깨지지 않음)

zsh RPROMPT는 bats로 테스트하기 어려움 — manual smoke test 위주.

- [ ] **Step 3.1: zshrc.shared 에 segment 추가**

`shell/zshrc.shared` 끝에 추가:

```bash
# ── HUD: 두 맥북 상태 RPROMPT segment ──────────────
__claude_sync_hud_rprompt() {
  # silent fail: 스크립트 없으면 비움
  [[ -x "$HOME/.config/claude-sync/bin/hud-machines.sh" ]] || return 0
  "$HOME/.config/claude-sync/bin/hud-machines.sh" --format=line 2>/dev/null
}

# 기존 RPROMPT 보존하면서 끝에 HUD 추가
if [[ -z "${__CLAUDE_SYNC_RPROMPT_SET:-}" ]]; then
  RPROMPT='${RPROMPT:-}$(__claude_sync_hud_rprompt)'
  export __CLAUDE_SYNC_RPROMPT_SET=1
fi
```

- [ ] **Step 3.2: 자기 PC manual smoke test**

```bash
exec zsh   # 새 셸
# Prompt 오른쪽에 "🏠 홈맥에어 ●  💼 회사맥프로 ..." 표시되는지 확인
echo "test"  # 다음 prompt 도 표시
```

빠른 keystroke 시 prompt가 늦지 않는지 (5s 캐시 덕분에 첫 호출 외 즉시):
```bash
for i in 1 2 3 4 5; do echo $i; done
```

- [ ] **Step 3.3: 회귀 — 전체 bats 통과**

```bash
cd ~/.config/claude-sync && bats tests/
# Expected: 모든 tests pass (zsh RPROMPT 변경은 bats 영향 없음)
```

- [ ] **Step 3.4: 커밋**

```bash
cd ~/.config/claude-sync
git add shell/zshrc.shared
git commit -m "feat(hud): zsh RPROMPT segment — 매 prompt 두 맥북 상태

- __claude_sync_hud_rprompt() 함수 추가
- silent fail (스크립트 없어도 prompt 깨지지 않음)
- 5초 캐시 덕분에 keystroke 부담 없음"
```

---

## Task 4: Claude statusline (omc-hud.mjs) 통합 + 5초 ✨반짝

**Files:**
- Modify: `claude/hud/omc-hud.mjs` (segment 추가)
- Modify: `bin/hud-machines.sh` (`--format=line` 에 ✨반짝 인디케이터 추가)
- Create: `state/hud-flash.txt` (활동 도착 마커, gitignored)

**기능:**
- Claude Code statusline 에 두 맥북 segment 추가
- 새 ledger 이벤트 도착 → `state/hud-flash.txt` 에 마커 시각 기록
- `hud-machines.sh --format=line` 이 마커가 5초 이내면 출력에 추가 정보 prepend (예: `✨ 방금 lawblaw 끝!`)

**flash 트리거 메커니즘:**
- `notify-activity.sh` (Phase 1) 가 자기 머신 활동 시 ledger 추가
- 다른 머신에서 git pull 받으면 그 변경이 도착 — 단 zsh는 자동 감지 X
- → 이번 task 에서는 단순화: `state/hud-flash.txt` 를 manual 호출로 set 하는 인터페이스만 + `--format=line` 의 표시 로직만

**Note:** 자동 감지(git pull 후 자동 trigger)는 Phase 2.5 또는 별도 sub-task. 일단 인프라만.

- [ ] **Step 4.1: 실패 테스트 추가**

`tests/hud-machines.bats` 끝에 추가:

```bash
@test "hud-machines --format=line prepends flash when state/hud-flash.txt < 5s old" {
  setup_persona_and_ledgers
  # flash 마커 생성 (방금)
  echo "lawblaw 끝!" > "$SSOT/state/hud-flash.txt"
  run "$SSOT/bin/hud-machines.sh" --format=line --no-cache
  [ "$status" -eq 0 ]
  [[ "$output" == *"✨"* ]]
  [[ "$output" == *"lawblaw 끝"* ]]
}

@test "hud-machines --format=line ignores flash older than 5s" {
  setup_persona_and_ledgers
  echo "stale flash" > "$SSOT/state/hud-flash.txt"
  # 6초 이전으로 mtime 조작
  touch -A -10 "$SSOT/state/hud-flash.txt" 2>/dev/null || touch -t "$(date -v-1M +%Y%m%d%H%M)" "$SSOT/state/hud-flash.txt"
  run "$SSOT/bin/hud-machines.sh" --format=line --no-cache
  [[ "$output" != *"stale flash"* ]]
}
```

- [ ] **Step 4.2: 테스트 실패 확인**

```bash
cd ~/.config/claude-sync && bats tests/hud-machines.bats
# Expected: 13 tests, 2 새 failures
```

- [ ] **Step 4.3: hud-machines.sh 에 flash 로직 추가**

`bin/hud-machines.sh` 의 `if [[ "$format" == "line" ]]; then` 블록에서 출력 직전에 다음 추가:

```bash
if [[ "$format" == "line" ]]; then
  # 5초 이내 flash 마커 있으면 prepend
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
```

- [ ] **Step 4.4: 테스트 통과 확인**

```bash
cd ~/.config/claude-sync && bats tests/hud-machines.bats
# Expected: 13 tests, 0 failures
```

- [ ] **Step 4.5: omc-hud.mjs 확장**

먼저 omc-hud.mjs 구조 확인:
```bash
head -50 ~/.config/claude-sync/claude/hud/omc-hud.mjs
```

기존 구조에 따라 새 segment 추가. 일반적으로 segment 함수 패턴:

`claude/hud/omc-hud.mjs` 끝부분에 (또는 segment 등록 함수에) 다음 추가:

```javascript
// Two-mac HUD segment (Phase 2)
async function twoMacSegment() {
  try {
    const { execSync } = await import('node:child_process');
    const out = execSync(
      `${process.env.HOME}/.config/claude-sync/bin/hud-machines.sh --format=line`,
      { encoding: 'utf-8', timeout: 1000 }
    );
    return out.trim();
  } catch {
    return ''; // silent fail
  }
}

// 기존 segment 등록 시스템에 따라 등록
// 예: segments.push(twoMacSegment);
```

**Note:** omc-hud.mjs 의 정확한 segment 등록 패턴은 파일 구조를 보고 적용. 등록 메커니즘이 명시적이지 않으면 main 출력 함수에 직접 await 호출 추가.

- [ ] **Step 4.6: state/hud-flash.txt gitignore**

`.gitignore` 끝에 추가:
```
# HUD flash 마커 (머신별)
state/hud-flash.txt
```

- [ ] **Step 4.7: 커밋**

```bash
cd ~/.config/claude-sync
git add bin/hud-machines.sh tests/hud-machines.bats claude/hud/omc-hud.mjs .gitignore
git commit -m "feat(hud): 5초 ✨반짝 인디케이터 + Claude statusline segment

- bin/hud-machines.sh: state/hud-flash.txt < 5s 시 prefix 추가
- claude/hud/omc-hud.mjs: twoMacSegment (subprocess + silent fail)
- 2 추가 tests (총 13)"
```

---

## Task 5: summarize-session.sh — 세션 헤드라인 합성

**Files:**
- Create: `bin/summarize-session.sh`
- Create: `tests/summarize-session.bats`

**기능:**
- 입력: cwd / duration_min / commits / files_changed
- 출력: 사람 친화 헤드라인 (Telegram 메시지용)
- 가장 최근 git commit 메시지 자동 추출 (cwd 기준)

**호출 예:**
```bash
summarize-session.sh /dev/lawblaw_dev 22 3 12
# → "lawblaw_dev · "fix(auth): SSO 토큰 검증" · 22분 · 3 commits"
```

- [ ] **Step 5.1: 실패 테스트 작성**

Create `tests/summarize-session.bats`:

```bash
# tests/summarize-session.bats
load test_helper

@test "summarize-session formats minimal info" {
  run "$SSOT/bin/summarize-session.sh" "/tmp/myproject" 15 0 5
  [ "$status" -eq 0 ]
  [[ "$output" == *"myproject"* ]]
  [[ "$output" == *"15분"* ]]
  [[ "$output" == *"5 files"* ]]
}

@test "summarize-session shows commit count" {
  run "$SSOT/bin/summarize-session.sh" "/tmp/myproject" 22 3 12
  [[ "$output" == *"3 commits"* ]]
}

@test "summarize-session reads last commit message from cwd if it's a git repo" {
  # 임시 git repo 생성
  tmp_repo=$(mktemp -d)
  cd "$tmp_repo"
  git init -q
  git config user.email "t@t" && git config user.name "t"
  echo "x" > a.txt
  git add a.txt
  git commit -q -m "fix(auth): SSO 토큰 검증"

  cd "$SSOT"
  run "$SSOT/bin/summarize-session.sh" "$tmp_repo" 22 1 1
  [[ "$output" == *"SSO 토큰 검증"* ]]
  rm -rf "$tmp_repo"
}

@test "summarize-session handles non-git cwd gracefully" {
  tmp_dir=$(mktemp -d)
  run "$SSOT/bin/summarize-session.sh" "$tmp_dir" 5 0 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"5분"* ]]
  rm -rf "$tmp_dir"
}

@test "summarize-session uses basename of cwd" {
  run "$SSOT/bin/summarize-session.sh" "/Users/x/dev/lawblaw_dev" 10 1 3
  [[ "$output" == *"lawblaw_dev"* ]]
  # 전체 경로는 표시 안 함
  [[ "$output" != *"/Users/x/dev/lawblaw_dev"* ]]
}
```

- [ ] **Step 5.2: 테스트 실패 확인**

```bash
cd ~/.config/claude-sync && bats tests/summarize-session.bats
# Expected: 5 tests, 5 failures
```

- [ ] **Step 5.3: summarize-session.sh 구현**

Create `bin/summarize-session.sh`:

```bash
#!/usr/bin/env bash
# summarize-session.sh — 세션 헤드라인 합성
# 사용법:
#   summarize-session.sh <cwd> <duration_min> <commits> <files_changed>
# 예:
#   summarize-session.sh /dev/lawblaw 22 3 12

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

# git repo면 마지막 commit 메시지 추출
last_msg=""
if [[ -d "$cwd/.git" ]]; then
  last_msg=$(git -C "$cwd" log -1 --format=%s 2>/dev/null || true)
fi

# 헤드라인 합성
parts=("$base")
[[ -n "$last_msg" ]] && parts+=("\"$last_msg\"")
parts+=("${duration}분")
parts+=("$commits commits")
parts+=("$files files")

# " · " 로 join
out=""
for p in "${parts[@]}"; do
  if [[ -z "$out" ]]; then
    out="$p"
  else
    out="$out · $p"
  fi
done

echo "$out"
```

권한: `chmod +x ~/.config/claude-sync/bin/summarize-session.sh`

- [ ] **Step 5.4: 테스트 통과 확인**

```bash
cd ~/.config/claude-sync && bats tests/summarize-session.bats
# Expected: 5 tests, 0 failures
```

- [ ] **Step 5.5: 커밋**

```bash
cd ~/.config/claude-sync
git add bin/summarize-session.sh tests/summarize-session.bats
git commit -m "feat(activity): summarize-session.sh — 헤드라인 합성

- cwd basename + 마지막 git commit msg + duration + commits + files
- 5 bats tests"
```

---

## Task 6: notify-session-end.sh — Stop hook 트리거

**Files:**
- Create: `bin/notify-session-end.sh`
- Create: `tests/notify-session-end.bats`

**기능:**
- Claude Code Stop hook 이 호출하는 진입점
- 활동 의미 있는지 판단 (≥3분 또는 ≥1commit)
- 의미 있으면 `summarize-session.sh` + `notify-activity.sh session_end` 호출 (3채널 발사)
- 의미 없으면 silent skip

**Stop hook의 stdin format**: Claude Code 가 JSON 으로 session 정보 stdin 으로 전달. 단순화: cwd 와 session start ts 만 사용.

**호출 환경**:
- Stop hook stdin: `{ "session_id": "...", "transcript_path": "...", "stop_hook_active": false }` 같은 JSON
- 우리는 cwd 는 `$PWD` 또는 transcript path 의 부모 디렉터리에서 추정
- Session 시작 시각은 ledger의 마지막 `session_start` 이벤트로부터 (없으면 -10분 default)

- [ ] **Step 6.1: 실패 테스트 작성**

Create `tests/notify-session-end.bats`:

```bash
# tests/notify-session-end.bats
load test_helper

setup_persona_and_session() {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  # 5분 전 session_start
  TS_START=$(date -v-5M +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  echo "{\"ts\":\"$TS_START\",\"host\":\"홈맥에어\",\"type\":\"session_start\",\"cwd\":\"/tmp/proj\"}" \
    > "$SSOT/state/activity/홈맥에어.jsonl"
}

@test "notify-session-end skips short session (<3min, 0 commits)" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  TS_START=$(date -v-1M +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  echo "{\"ts\":\"$TS_START\",\"host\":\"홈맥에어\",\"type\":\"session_start\",\"cwd\":\"/tmp/proj\"}" \
    > "$SSOT/state/activity/홈맥에어.jsonl"

  # 짧은 세션 (1분), commits 0
  DRY_RUN=1 run "$SSOT/bin/notify-session-end.sh" "/tmp/proj"
  [ "$status" -eq 0 ]
  # session_end 이벤트 추가 안 됨 (skip)
  count=$(grep -c "session_end" "$SSOT/state/activity/홈맥에어.jsonl" 2>/dev/null || echo 0)
  [ "$count" = "0" ]
}

@test "notify-session-end runs full notify on long session (≥3min)" {
  setup_persona_and_session
  # 5분 세션, commits 0 (≥3분 통과)
  DRY_RUN=1 run "$SSOT/bin/notify-session-end.sh" "/tmp/proj"
  [ "$status" -eq 0 ]
}

@test "notify-session-end recognizes commit-only sessions (<3min but ≥1commit)" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  TS_START=$(date -v-1M +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  TS_NOW=$(date +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  cat > "$SSOT/state/activity/홈맥에어.jsonl" <<EOF
{"ts":"$TS_START","host":"홈맥에어","type":"session_start","cwd":"/tmp/proj"}
{"ts":"$TS_NOW","host":"홈맥에어","type":"commit","sha":"abc1"}
EOF
  DRY_RUN=1 run "$SSOT/bin/notify-session-end.sh" "/tmp/proj"
  [ "$status" -eq 0 ]
}

@test "notify-session-end handles missing session_start gracefully" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  # session_start 없음
  DRY_RUN=1 run "$SSOT/bin/notify-session-end.sh" "/tmp/proj"
  [ "$status" -eq 0 ]
  # silent skip (default duration 0)
}

@test "notify-session-end appends session_end event when meaningful" {
  setup_persona_and_session
  # DRY_RUN 없음 — 진짜 ledger 추가
  run "$SSOT/bin/notify-session-end.sh" "/tmp/proj"
  [ "$status" -eq 0 ]
  count=$(grep -c "session_end" "$SSOT/state/activity/홈맥에어.jsonl")
  [ "$count" -ge "1" ]
}
```

- [ ] **Step 6.2: 테스트 실패 확인**

```bash
cd ~/.config/claude-sync && bats tests/notify-session-end.bats
# Expected: 5 tests, 5 failures
```

- [ ] **Step 6.3: notify-session-end.sh 구현**

Create `bin/notify-session-end.sh`:

```bash
#!/usr/bin/env bash
# notify-session-end.sh — Claude Code Stop hook 트리거
# 사용법:
#   notify-session-end.sh [cwd]
# 환경 변수:
#   DRY_RUN=1   — Telegram/git push skip (테스트용)
#
# 동작:
#   1. ledger 에서 마지막 session_start 의 ts 조회 → duration 계산
#   2. 그 사이의 commit 이벤트 카운트
#   3. duration ≥3분 OR commits ≥1 이면 notify-activity.sh session_end ... 호출
#      그 외엔 silent skip
#   4. summarize-session.sh 로 헤드라인 합성

set -uo pipefail

SSOT="$HOME/.config/claude-sync"
PERSONA_BIN="$SSOT/bin/persona.sh"
LEDGER_DIR="$SSOT/state/activity"
NOTIFY_BIN="$SSOT/bin/notify-activity.sh"
SUMMARIZE_BIN="$SSOT/bin/summarize-session.sh"

cwd="${1:-$PWD}"
persona=$("$PERSONA_BIN" 2>/dev/null) || exit 0
ledger="$LEDGER_DIR/$persona.jsonl"
[[ -f "$ledger" ]] || exit 0

# 마지막 session_start 의 ts
last_start=$(jq -r 'select(.type == "session_start") | .ts' "$ledger" 2>/dev/null | tail -1)
if [[ -z "$last_start" || "$last_start" == "null" ]]; then
  exit 0  # session_start 없음 — skip
fi

# duration 계산 (분)
ts_no_tz="${last_start%%[+-]*}"
tz_part="${last_start:${#ts_no_tz}}"
tz_compact="${tz_part//:/}"
start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "${ts_no_tz}${tz_compact}" +%s 2>/dev/null || echo 0)
now_epoch=$(date +%s)
duration_min=$(( (now_epoch - start_epoch) / 60 ))

# 그 사이의 commits 카운트
commits=$(jq -r --arg t "$last_start" \
  'select(.type == "commit" and .ts >= $t) | .sha' \
  "$ledger" 2>/dev/null | wc -l | tr -d ' ')

# files_changed: ledger에 자동 기록 X — 일단 0 default
files_changed=0

# 의미 있는 세션 판단
if (( duration_min < 3 && commits < 1 )); then
  exit 0  # silent skip
fi

# 헤드라인 합성
summary=$("$SUMMARIZE_BIN" "$cwd" "$duration_min" "$commits" "$files_changed" 2>/dev/null || echo "$cwd · ${duration_min}분")

# notify-activity 호출
"$NOTIFY_BIN" session_end \
  "cwd=$cwd" \
  "duration_min=$duration_min" \
  "commits=$commits" \
  "files_changed=$files_changed" \
  "summary=$summary" || true
```

권한: `chmod +x ~/.config/claude-sync/bin/notify-session-end.sh`

- [ ] **Step 6.4: 테스트 통과 확인**

```bash
cd ~/.config/claude-sync && bats tests/notify-session-end.bats
# Expected: 5 tests, 0 failures
```

- [ ] **Step 6.5: 커밋**

```bash
cd ~/.config/claude-sync
git add bin/notify-session-end.sh tests/notify-session-end.bats
git commit -m "feat(activity): notify-session-end.sh — Stop hook 트리거

- ledger의 session_start 기준 duration 계산
- ≥3분 또는 ≥1commit 시만 notify-activity 호출
- DRY_RUN=1 테스트 지원
- 5 bats tests"
```

---

## Task 7: Claude Stop hook 등록

**Files:**
- Modify: `claude/settings.shared.json` (Stop 배열에 notify-session-end.sh 추가)
- Modify: `~/.claude/settings.json` (동기 적용)

**기능:**
- Claude Code 응답 끝날 때마다 `notify-session-end.sh` 자동 호출
- 기존 hooks (quality-check.py, notify.sh, rebuild-agents-md) 보존

- [ ] **Step 7.1: 변경 사전 검증 — 기존 Stop hook 구조 확인**

```bash
jq '.hooks.Stop' ~/.claude/settings.json
# 출력: [{"matcher":"*","hooks":[ {quality-check.py}, {notify.sh} ]}]
```

- [ ] **Step 7.2: jq로 새 hook 추가**

`~/.claude/settings.json` 와 `~/.config/claude-sync/claude/settings.shared.json` 둘 다:

```bash
for f in ~/.claude/settings.json ~/.config/claude-sync/claude/settings.shared.json; do
  jq '(.hooks.Stop[] | select(.matcher == "*") | .hooks) += [
    {"type":"command","command":"bash /Users/denny/.config/claude-sync/bin/notify-session-end.sh &"}
  ]' "$f" > "$f.new" && mv "$f.new" "$f"
done
```

`&` 백그라운드 실행 — Stop hook 부담 최소화.

- [ ] **Step 7.3: jq 검증**

```bash
jq '.hooks.Stop[0].hooks | length' ~/.claude/settings.json
# Expected: 3 (quality-check + notify.sh + notify-session-end.sh)

jq '.hooks.Stop[0].hooks[2].command' ~/.claude/settings.json
# Expected: "bash /Users/denny/.config/claude-sync/bin/notify-session-end.sh &"
```

- [ ] **Step 7.4: 다음 Claude 응답 후 manual smoke**

응답 끝나면 백그라운드로 notify-session-end 호출됨. ledger 변동 확인:
```bash
sleep 5
tail -1 ~/.config/claude-sync/state/activity/홈맥에어.jsonl
# 의미 있는 세션이면 session_end 이벤트 추가됨
```

- [ ] **Step 7.5: 커밋**

```bash
cd ~/.config/claude-sync
git add claude/settings.shared.json
git commit -m "feat(activity): Stop hook — notify-session-end 등록

- claude/settings.shared.json 의 Stop 배열에 notify-session-end.sh 추가
- 백그라운드(&) 실행으로 Claude 응답 부담 최소화
- (~/.claude/settings.json 도 동기 — 머신별 로컬 파일)"
```

---

## Task 8: hud-catchup.sh + zsh precmd 출퇴근 모먼트

**Files:**
- Create: `bin/hud-catchup.sh`
- Create: `tests/hud-catchup.bats`
- Modify: `shell/zshrc.shared` (precmd hook 추가)

**기능:**
- 마지막 prompt 시각을 `state/last-prompt-ts.txt` 에 기록
- 다음 prompt 시 4시간+ 휴면이면 catchup 메시지 표시 (1회만)
- 메시지: 상대 머신의 어제(또는 휴면 사이) 활동 요약

- [ ] **Step 8.1: 실패 테스트 작성**

Create `tests/hud-catchup.bats`:

```bash
# tests/hud-catchup.bats
load test_helper

setup_persona() {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
}

@test "hud-catchup silent if no last-prompt-ts" {
  setup_persona
  run "$SSOT/bin/hud-catchup.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ]  # 첫 사용 — 표시 X
}

@test "hud-catchup silent if last-prompt < 4h ago" {
  setup_persona
  date +%s > "$SSOT/state/last-prompt-ts.txt"
  run "$SSOT/bin/hud-catchup.sh"
  [ -z "$output" ]
}

@test "hud-catchup shows other machine activity if last-prompt ≥ 4h ago" {
  setup_persona
  # 5시간 전 prompt
  echo "$(( $(date +%s) - 18000 ))" > "$SSOT/state/last-prompt-ts.txt"
  # 상대 머신의 어제 활동
  TS_YEST=$(date -v-1d +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  echo "{\"ts\":\"$TS_YEST\",\"host\":\"회사맥프로\",\"type\":\"session_end\",\"cwd\":\"/dev/lawblaw\",\"duration_min\":22}" \
    > "$SSOT/state/activity/회사맥프로.jsonl"

  run "$SSOT/bin/hud-catchup.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"홈맥에어 깨어남"* ]]
  [[ "$output" == *"회사맥프로"* ]]
  [[ "$output" == *"lawblaw"* ]]
}

@test "hud-catchup updates last-prompt-ts after display" {
  setup_persona
  echo "$(( $(date +%s) - 18000 ))" > "$SSOT/state/last-prompt-ts.txt"
  TS_YEST=$(date -v-1d +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  echo "{\"ts\":\"$TS_YEST\",\"host\":\"회사맥프로\",\"type\":\"wake\"}" \
    > "$SSOT/state/activity/회사맥프로.jsonl"

  run "$SSOT/bin/hud-catchup.sh"
  # 호출 후 last-prompt-ts 가 현재 시각 근처
  ts_after=$(cat "$SSOT/state/last-prompt-ts.txt")
  ts_now=$(date +%s)
  diff=$(( ts_now - ts_after ))
  [ "$diff" -lt "5" ]
}
```

- [ ] **Step 8.2: 테스트 실패 확인**

```bash
cd ~/.config/claude-sync && bats tests/hud-catchup.bats
# Expected: 4 tests, 4 failures
```

- [ ] **Step 8.3: hud-catchup.sh 구현**

Create `bin/hud-catchup.sh`:

```bash
#!/usr/bin/env bash
# hud-catchup.sh — 4시간+ 휴면 후 첫 prompt 시 어제 활동 표시
# 매 호출 마지막에 last-prompt-ts 갱신

set -uo pipefail

SSOT="$HOME/.config/claude-sync"
PERSONA_BIN="$SSOT/bin/persona.sh"
LEDGER_DIR="$SSOT/state/activity"
TS_FILE="$SSOT/state/last-prompt-ts.txt"

now_epoch=$(date +%s)

# 마지막 prompt 시각 조회
if [[ ! -f "$TS_FILE" ]]; then
  # 첫 호출 — silent + ts 기록
  echo "$now_epoch" > "$TS_FILE"
  exit 0
fi

last_epoch=$(cat "$TS_FILE" 2>/dev/null || echo 0)
diff=$(( now_epoch - last_epoch ))

# ts 갱신 (이번 prompt 시각)
echo "$now_epoch" > "$TS_FILE"

# 4시간 미만이면 silent
if (( diff < 14400 )); then
  exit 0
fi

# 4시간+ 휴면 → catchup 메시지
hours=$(( diff / 3600 ))
self=$("$PERSONA_BIN" 2>/dev/null) || exit 0
self_emoji=$(echo $("$PERSONA_BIN" --json) | jq -r '.emoji')
other=$("$PERSONA_BIN" --other 2>/dev/null) || exit 0
other_emoji="💼"
[[ "$self" == "회사맥프로" ]] && other_emoji="🏠"

echo "$self_emoji $self 깨어남 (${hours}시간 만에)"
echo ""

# 상대 머신의 휴면 사이 활동 (last_epoch 이후)
last_iso=$(date -j -f %s "$last_epoch" +%Y-%m-%dT%H:%M:%S%z 2>/dev/null | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
other_ledger="$LEDGER_DIR/$other.jsonl"

if [[ -f "$other_ledger" ]]; then
  echo "$other_emoji $other 한 일:"
  jq -r --arg since "$last_iso" \
    'select(.type == "session_end" and .ts >= $since) |
     "  • \(.cwd // "?") · \(.duration_min // "?")분" + (if .summary then " · \"\(.summary)\"" else "" end)' \
    "$other_ledger" 2>/dev/null | head -5

  # 그 외 commit 카운트
  other_commits=$(jq -r --arg since "$last_iso" \
    'select(.type == "commit" and .ts >= $since) | .sha' \
    "$other_ledger" 2>/dev/null | wc -l | tr -d ' ')
  if (( other_commits > 0 )); then
    echo "  • 그 외 commit ${other_commits}개"
  fi

  # 상대가 빈 결과면 (활동 없음)
  has_activity=$(jq -r --arg since "$last_iso" \
    'select(.ts >= $since) | .ts' "$other_ledger" 2>/dev/null | head -1)
  if [[ -z "$has_activity" ]]; then
    echo "  (활동 없음)"
  fi
fi
```

권한: `chmod +x ~/.config/claude-sync/bin/hud-catchup.sh`

- [ ] **Step 8.4: 테스트 통과 확인**

```bash
cd ~/.config/claude-sync && bats tests/hud-catchup.bats
# Expected: 4 tests, 0 failures
```

- [ ] **Step 8.5: zsh precmd hook 추가**

`shell/zshrc.shared` 끝에 추가:

```bash
# ── HUD: 출퇴근 catchup (4시간+ 휴면 후 1회) ──────────
__claude_sync_catchup() {
  [[ -x "$HOME/.config/claude-sync/bin/hud-catchup.sh" ]] || return 0
  local out
  out=$("$HOME/.config/claude-sync/bin/hud-catchup.sh" 2>/dev/null)
  [[ -n "$out" ]] && echo "$out"
}

if [[ -z "${__CLAUDE_SYNC_CATCHUP_HOOKED:-}" ]]; then
  autoload -Uz add-zsh-hook 2>/dev/null
  add-zsh-hook precmd __claude_sync_catchup 2>/dev/null
  export __CLAUDE_SYNC_CATCHUP_HOOKED=1
fi
```

- [ ] **Step 8.6: state/last-prompt-ts.txt gitignore**

`.gitignore` 끝에:
```
# 머신별 prompt 시각 마커
state/last-prompt-ts.txt
```

- [ ] **Step 8.7: 커밋**

```bash
cd ~/.config/claude-sync
git add bin/hud-catchup.sh tests/hud-catchup.bats shell/zshrc.shared .gitignore
git commit -m "feat(hud): hud-catchup.sh — 4시간+ 휴면 후 출퇴근 모먼트

- 매 prompt 시각 state/last-prompt-ts.txt 갱신
- 4h+ 휴면 시 상대 머신의 그 사이 활동 표시
- zsh precmd hook 자동 트리거
- 4 bats tests"
```

---

## Task 9: 일일 요약 launchd

**Files:**
- Create: `bin/daily-digest.sh`
- Create: `tests/daily-digest.bats`
- Create: `launchd/com.denny.claude-sync-digest.plist`

**기능:**
- 매일 아침 08:00 launchd 트리거
- 어제 활동 통합 → Telegram 푸시
- 양 머신의 sessions/duration/commits 합계

- [ ] **Step 9.1: 실패 테스트 작성**

Create `tests/daily-digest.bats`:

```bash
# tests/daily-digest.bats
load test_helper

setup_yesterday_ledgers() {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  TS_YEST=$(date -v-1d +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  cat > "$SSOT/state/activity/홈맥에어.jsonl" <<EOF
{"ts":"$TS_YEST","host":"홈맥에어","type":"session_end","cwd":"/dev/x","duration_min":47,"commits":5}
EOF
  cat > "$SSOT/state/activity/회사맥프로.jsonl" <<EOF
{"ts":"$TS_YEST","host":"회사맥프로","type":"session_end","cwd":"/dev/y","duration_min":72,"commits":7}
EOF
}

@test "daily-digest --print shows yesterday summary" {
  setup_yesterday_ledgers
  run "$SSOT/bin/daily-digest.sh" --print
  [ "$status" -eq 0 ]
  [[ "$output" == *"오늘의 두 맥북"* ]] || [[ "$output" == *"어제의 두 맥북"* ]]
  [[ "$output" == *"홈맥에어"* ]]
  [[ "$output" == *"회사맥프로"* ]]
}

@test "daily-digest aggregates session counts" {
  setup_yesterday_ledgers
  run "$SSOT/bin/daily-digest.sh" --print
  [[ "$output" == *"1 sessions"* ]]
}

@test "daily-digest aggregates duration" {
  setup_yesterday_ledgers
  run "$SSOT/bin/daily-digest.sh" --print
  [[ "$output" == *"47"* ]]
  [[ "$output" == *"72"* ]]
}

@test "daily-digest handles empty ledgers gracefully" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  run "$SSOT/bin/daily-digest.sh" --print
  [ "$status" -eq 0 ]
  # 활동 없어도 헤더는 표시
  [[ "$output" == *"두 맥북"* ]]
}
```

- [ ] **Step 9.2: 테스트 실패 확인**

```bash
cd ~/.config/claude-sync && bats tests/daily-digest.bats
# Expected: 4 tests, 4 failures
```

- [ ] **Step 9.3: daily-digest.sh 구현**

Create `bin/daily-digest.sh`:

```bash
#!/usr/bin/env bash
# daily-digest.sh — 어제 활동 통합 요약
# 사용법:
#   daily-digest.sh           Telegram 으로 push
#   daily-digest.sh --print   stdout 출력 (테스트/디버그용)

set -uo pipefail

SSOT="$HOME/.config/claude-sync"
LEDGER_DIR="$SSOT/state/activity"
SETTINGS="$HOME/.claude/settings.local.json"

mode="${1:-push}"
yesterday=$(date -v-1d +%Y-%m-%d)

# 페르소나 별 집계
total_sessions=0
total_duration=0
total_commits=0
out=""
out+="📊 어제의 두 맥북 ($yesterday)\n\n"

for ledger in "$LEDGER_DIR"/*.jsonl; do
  [[ -f "$ledger" ]] || continue
  persona=$(basename "$ledger" .jsonl)

  emoji="🏠"
  [[ "$persona" == "회사맥프로" ]] && emoji="💼"

  sessions=$(jq -r --arg d "$yesterday" \
    'select(.type == "session_end" and (.ts | startswith($d))) | .duration_min' \
    "$ledger" 2>/dev/null | wc -l | tr -d ' ')
  duration=$(jq -r --arg d "$yesterday" \
    '[select(.type == "session_end" and (.ts | startswith($d))) | (.duration_min // 0)] | add // 0' \
    "$ledger" 2>/dev/null)
  commits=$(jq -r --arg d "$yesterday" \
    '[select(.type == "session_end" and (.ts | startswith($d))) | (.commits // 0)] | add // 0' \
    "$ledger" 2>/dev/null)

  out+="$emoji $persona · $sessions sessions · ${duration}분 · ${commits} commits\n"
  total_sessions=$(( total_sessions + sessions ))
  total_duration=$(( total_duration + duration ))
  total_commits=$(( total_commits + commits ))
done

out+="\n총 ${total_duration}분 · ${total_commits} commits"

if [[ "$mode" == "--print" ]]; then
  printf "$out\n"
else
  # Telegram push
  if [[ -f "$SETTINGS" ]]; then
    token=$(jq -r '.env.TELEGRAM_TOKEN // empty' "$SETTINGS" 2>/dev/null)
    chat_id=$(jq -r '.env.TELEGRAM_CHAT_ID // empty' "$SETTINGS" 2>/dev/null)
    if [[ -n "$token" && -n "$chat_id" ]]; then
      printf "$out" | curl -sS -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        --max-time 5 \
        --data-urlencode "chat_id=${chat_id}" \
        --data-urlencode "text@-" \
        >/dev/null 2>&1 || true
    fi
  fi
fi
```

권한: `chmod +x ~/.config/claude-sync/bin/daily-digest.sh`

- [ ] **Step 9.4: 테스트 통과 확인**

```bash
cd ~/.config/claude-sync && bats tests/daily-digest.bats
# Expected: 4 tests, 0 failures
```

- [ ] **Step 9.5: launchd plist 작성**

Create `launchd/com.denny.claude-sync-digest.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.denny.claude-sync-digest</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>$HOME/.config/claude-sync/bin/daily-digest.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>8</integer>
    <key>Minute</key>
    <integer>0</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>/tmp/claude-sync-digest.out.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/claude-sync-digest.err.log</string>
  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
```

- [ ] **Step 9.6: launchd 등록 (자기 PC 실측)**

```bash
cp ~/.config/claude-sync/launchd/com.denny.claude-sync-digest.plist \
   ~/Library/LaunchAgents/

launchctl load ~/Library/LaunchAgents/com.denny.claude-sync-digest.plist

launchctl list | grep claude-sync-digest
# Expected: PID 또는 - 와 status 0
```

- [ ] **Step 9.7: 커밋**

```bash
cd ~/.config/claude-sync
git add bin/daily-digest.sh tests/daily-digest.bats launchd/com.denny.claude-sync-digest.plist
git commit -m "feat(activity): daily-digest.sh + launchd plist (매일 08:00)

- bin/daily-digest.sh: 어제 sessions/duration/commits 통합 요약
- --print 모드 (테스트/디버그) + 기본 Telegram push
- launchd com.denny.claude-sync-digest.plist (StartCalendarInterval 08:00)
- 4 bats tests"
```

---

## Task 10: doctor Phase 2 검증 + 통합 확인

**Files:**
- Modify: `bin/doctor.sh` (Phase 2 섹션 추가)

- [ ] **Step 10.1: doctor.sh 에 검증 섹션 추가**

`bin/doctor.sh` 의 마지막 `echo ""; [[ $errors -eq 0 ]]` **직전**에 추가:

```bash
echo ""
echo "── Phase 2: HUD + Stop hook + Catchup ──"

# Phase 2 helper 실행 권한
for s in bin/hud-machines.sh bin/summarize-session.sh bin/notify-session-end.sh bin/hud-catchup.sh bin/daily-digest.sh; do
  if [[ -x "$SSOT/$s" ]]; then
    echo "✓ $s"
  else
    echo "❌ $s 실행 권한/존재 X"; ((errors++))
  fi
done

# state 디렉터리들
[[ -d "$SSOT/state/hud-cache" ]] && echo "✓ state/hud-cache" || { echo "⚠ state/hud-cache 없음"; }

# zsh RPROMPT segment 등록
if grep -q "__claude_sync_hud_rprompt" "$SSOT/shell/zshrc.shared" 2>/dev/null; then
  echo "✓ zsh RPROMPT segment 등록"
else
  echo "❌ RPROMPT segment 미등록"; ((errors++))
fi

# Stop hook 등록 (notify-session-end)
if jq -e '.hooks.Stop[]?.hooks[]? | select(.command | contains("notify-session-end"))' "$HOME/.claude/settings.json" >/dev/null 2>&1; then
  echo "✓ Stop hook 에 notify-session-end 등록"
else
  echo "⚠ Stop hook trigger 미등록 — settings.shared.json + ~/.claude/settings.json 확인"
fi

# launchd digest plist
if launchctl list | grep -q "com.denny.claude-sync-digest"; then
  echo "✓ launchd digest 등록 (com.denny.claude-sync-digest)"
else
  echo "⚠ launchd digest 미등록 — launchd/com.denny.claude-sync-digest.plist 등록 필요"
fi
```

- [ ] **Step 10.2: doctor 실행 → 통과**

```bash
~/.config/claude-sync/bin/doctor.sh
# Expected: 새 Phase 2 섹션 모두 ✓ (또는 launchd 미등록 ⚠ — 자기 PC만 등록되면 OK)
```

- [ ] **Step 10.3: 모든 bats 회귀**

```bash
~/.config/claude-sync/bin/test.sh
# Expected: 모든 tests pass (Phase 1 + Phase 2 통합)
```

- [ ] **Step 10.4: Phase 2 마무리 커밋**

```bash
cd ~/.config/claude-sync
git add bin/doctor.sh
git commit -m "chore(doctor): Phase 2 검증 추가 — HUD + Stop hook + Catchup + 일일요약

Phase 2 완료. 다음: Phase 3 (C1 셋업 라이브 중계 + C5 첫 인사 모먼트)."
```

---

## Phase 2 완료 검증 체크리스트

이 plan 끝나면 다음이 모두 동작:

- [ ] `bin/hud-machines.sh --format=line` 양 맥북 상태 한 라인
- [ ] `bin/hud-machines.sh --format=detail` (alias `hudm`) 자세 정보
- [ ] zsh RPROMPT 에 매 prompt 두 맥북 상태 표시
- [ ] Claude statusline 에 두 맥북 segment 표시
- [ ] 5초 이내 새 활동 도착 시 ✨반짝 prefix
- [ ] `bin/summarize-session.sh` cwd + commit + duration → 헤드라인
- [ ] `bin/notify-session-end.sh` ≥3분 또는 ≥1commit 시만 push
- [ ] Claude Stop hook 이 notify-session-end 자동 호출
- [ ] 4시간+ 휴면 후 첫 prompt 시 catchup 메시지 1회
- [ ] 매일 08:00 launchd 가 daily-digest 트리거
- [ ] doctor 에 Phase 2 섹션 모두 ✓
- [ ] 총 bats 50+ tests pass

## 다음 Phase

Phase 3 (C1 + C5):
- bin/notify-step.sh — Telegram editMessageText 라이브 progress
- mac-setup.sh / bootstrap-new-mac.sh 의 step 함수 통합
- bin/greet.sh — 첫 인사 핸드셰이크 애니메이션
- zsh precmd hook 에 `__maybe_greet` 추가

Phase 3 plan 은 별도 파일: `docs/superpowers/plans/2026-04-29-dual-mac-presence-phase-3.md`
