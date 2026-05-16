# 두 맥북 살아있음 시스템 — Phase 1 (공통 인프라) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 양 맥북이 활동 ledger를 git으로 공유하고, 모든 와우 모먼트(C1~C5)가 그 위에 얹힐 수 있는 공통 인프라를 구축한다.

**Architecture:** `state/activity/{persona}.jsonl` 한 파일이 단일 진실 원천. 페르소나 helper로 hostname → persona 매핑. ledger append/query helper가 양 머신 데이터를 시간순 통합. `sync.sh --immediate` 모드로 git push latency를 30분 → ~30초로. 모든 후속 Phase가 이 인프라 위에서 동작.

**Tech Stack:** bash 3.2+ (macOS 기본), jq, bats-core (testing), git, Telegram bot API (Phase 1에서는 호출 인터페이스만 검증)

**전제 조건:**
- agent-harness-baseline repo가 `~/.config/agent-harness-baseline/` 에 clone됨
- jq, git 설치됨 (Brewfile에 이미 있음)
- 사용자 hostname이 macOS에서 `scutil --get LocalHostName` 으로 가져올 수 있음

---

## Task 0: bats-core 테스트 인프라 도입

**Files:**
- Modify: `bootstrap/Brewfile` (bats-core 추가)
- Create: `tests/test_helper.bash`
- Create: `tests/smoke.bats`
- Create: `bin/test.sh`

**TDD 적용 노트:** 이 task 자체는 인프라 도입. 첫 의미 있는 test는 Task 1부터.

- [ ] **Step 0.1: Brewfile에 bats-core 추가**

`bootstrap/Brewfile` 끝에 추가:

```ruby
# Bash testing framework (used in tests/)
brew "bats-core"
```

- [ ] **Step 0.2: bats-core 로컬 설치**

```bash
brew install bats-core
```

검증:
```bash
bats --version
# Expected: Bats 1.x.x
```

- [ ] **Step 0.3: 공통 test helper 작성**

Create `tests/test_helper.bash`:

```bash
# tests/test_helper.bash
# 모든 .bats 파일이 load 하는 공통 헬퍼

# 격리된 임시 작업 디렉터리 생성 (각 테스트마다)
setup() {
  export TEST_TMPDIR=$(mktemp -d -t agent-harness-baseline-test.XXXXXX)
  export ORIG_HOME="$HOME"
  export HOME="$TEST_TMPDIR"
  mkdir -p "$HOME/.config/agent-harness-baseline/state/activity"
  mkdir -p "$HOME/.config/agent-harness-baseline/bin"
  # SSOT 경로 노출
  export SSOT="$HOME/.config/agent-harness-baseline"
  # 실제 bin 스크립트 임시 환경에 복사 (테스트 대상)
  if [[ -d "$ORIG_HOME/.config/agent-harness-baseline/bin" ]]; then
    cp "$ORIG_HOME/.config/agent-harness-baseline/bin/"*.sh "$SSOT/bin/" 2>/dev/null || true
  fi
}

teardown() {
  export HOME="$ORIG_HOME"
  rm -rf "$TEST_TMPDIR"
}

# JSONL 한 줄 파싱 — assertion에 사용
jsonl_field() {
  local file="$1" line_num="$2" field="$3"
  sed -n "${line_num}p" "$file" | jq -r ".$field"
}
```

- [ ] **Step 0.4: smoke test 작성 + 실행**

Create `tests/smoke.bats`:

```bash
# tests/smoke.bats
load test_helper

@test "test_helper sets isolated HOME" {
  [[ "$HOME" == *"agent-harness-baseline-test."* ]]
  [ -d "$HOME/.config/agent-harness-baseline" ]
}

@test "jq is available" {
  run jq --version
  [ "$status" -eq 0 ]
}
```

실행:
```bash
cd ~/.config/agent-harness-baseline && bats tests/smoke.bats
# Expected: 2 tests, 0 failures
```

- [ ] **Step 0.5: bin/test.sh wrapper 작성**

Create `bin/test.sh`:

```bash
#!/usr/bin/env bash
# bin/test.sh — 모든 bats 테스트 실행
set -euo pipefail
SSOT="$HOME/.config/agent-harness-baseline"
cd "$SSOT" || exit 1

if ! command -v bats >/dev/null; then
  echo "❌ bats 미설치 — 'brew install bats-core'"
  exit 1
fi

bats tests/
```

권한:
```bash
chmod +x ~/.config/agent-harness-baseline/bin/test.sh
```

- [ ] **Step 0.6: 커밋**

```bash
cd ~/.config/agent-harness-baseline
git add bootstrap/Brewfile tests/ bin/test.sh
git commit -m "test: bats-core 테스트 인프라 도입

- Brewfile에 bats-core 추가
- tests/test_helper.bash: 격리된 HOME 환경
- tests/smoke.bats: sanity check
- bin/test.sh: wrapper alias

이후 Phase 1 모든 helper에 TDD 적용."
```

---

## Task 1: 페르소나 helper (`bin/persona.sh`)

**Files:**
- Create: `bin/persona.sh`
- Create: `tests/persona.bats`

**기능:**
- `persona.sh` (인자 없음) → 현재 머신의 페르소나 이름 출력
- `persona.sh --json` → 페르소나 + 색 + 이모지 JSON 출력
- `persona.sh --other` → 상대 머신 페르소나 이름 출력 (홈맥에어 ↔ 회사맥프로)
- `persona.sh --init` → `.machine.json` 없으면 hostname 기반 자동 추측 후 생성
- `~/.config/agent-harness-baseline/.machine.json` 이 권위 자료 (수동 override 가능)

**hostname 자동 매칭 규칙** (init 시):
- hostname에 `Air` 포함 → 홈맥에어 (핫핑크)
- hostname에 `Pro` 포함 → 회사맥프로 (블루)
- 그 외 → 홈맥에어 default + 사용자에게 stderr로 안내

- [ ] **Step 1.1: 실패하는 테스트 작성**

Create `tests/persona.bats`:

```bash
# tests/persona.bats
load test_helper

@test "persona.sh --init creates .machine.json with default for unknown hostname" {
  HOSTNAME_OVERRIDE="random-host" run "$SSOT/bin/persona.sh" --init
  [ "$status" -eq 0 ]
  [ -f "$SSOT/.machine.json" ]
  result=$(jq -r '.persona' "$SSOT/.machine.json")
  [ "$result" = "홈맥에어" ]
}

@test "persona.sh --init detects MacBook Air → 홈맥에어" {
  HOSTNAME_OVERRIDE="Dennys-MacBook-Air" run "$SSOT/bin/persona.sh" --init
  [ "$status" -eq 0 ]
  result=$(jq -r '.persona' "$SSOT/.machine.json")
  [ "$result" = "홈맥에어" ]
  emoji=$(jq -r '.emoji' "$SSOT/.machine.json")
  [ "$emoji" = "🏠" ]
}

@test "persona.sh --init detects MacBook Pro → 회사맥프로" {
  HOSTNAME_OVERRIDE="Dennys-MacBook-Pro" run "$SSOT/bin/persona.sh" --init
  [ "$status" -eq 0 ]
  result=$(jq -r '.persona' "$SSOT/.machine.json")
  [ "$result" = "회사맥프로" ]
  color=$(jq -r '.color' "$SSOT/.machine.json")
  [ "$color" = "#0969DA" ]
}

@test "persona.sh (no args) returns persona name from .machine.json" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  run "$SSOT/bin/persona.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "홈맥에어" ]
}

@test "persona.sh --json returns full JSON" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  run "$SSOT/bin/persona.sh" --json
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq -r '.persona')
  [ "$result" = "홈맥에어" ]
}

@test "persona.sh --other returns the other persona" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  run "$SSOT/bin/persona.sh" --other
  [ "$status" -eq 0 ]
  [ "$output" = "회사맥프로" ]
}

@test "persona.sh fails gracefully when .machine.json missing and not --init" {
  run "$SSOT/bin/persona.sh"
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 1.2: 테스트 실패 확인**

```bash
cd ~/.config/agent-harness-baseline && bats tests/persona.bats
# Expected: 7 tests, 7 failures (persona.sh 없음)
```

- [ ] **Step 1.3: persona.sh 구현**

Create `bin/persona.sh`:

```bash
#!/usr/bin/env bash
# persona.sh — 머신 페르소나 정의/조회
# 사용법:
#   persona.sh             현재 머신 페르소나 이름
#   persona.sh --json      페르소나 + 색 + 이모지 JSON
#   persona.sh --other     상대 머신 페르소나 이름
#   persona.sh --init      .machine.json 없으면 hostname 기반 자동 생성

set -uo pipefail

SSOT="$HOME/.config/agent-harness-baseline"
MACHINE_FILE="$SSOT/.machine.json"

# 테스트에서 hostname 주입 가능
HOSTNAME="${HOSTNAME_OVERRIDE:-$(scutil --get LocalHostName 2>/dev/null || hostname)}"

# 두 페르소나 정의 (단일 진실 원천)
HOME_PERSONA='{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493","label":"집"}'
WORK_PERSONA='{"persona":"회사맥프로","emoji":"💼","color":"#0969DA","label":"일"}'

case "${1:-}" in
  --init)
    if [[ -f "$MACHINE_FILE" ]]; then
      echo "ℹ️  $MACHINE_FILE 이미 존재 — skip" >&2
      exit 0
    fi
    if [[ "$HOSTNAME" == *Pro* ]]; then
      echo "$WORK_PERSONA" > "$MACHINE_FILE"
      echo "✓ 회사맥프로 (hostname '$HOSTNAME' 에 'Pro' 포함)" >&2
    elif [[ "$HOSTNAME" == *Air* ]]; then
      echo "$HOME_PERSONA" > "$MACHINE_FILE"
      echo "✓ 홈맥에어 (hostname '$HOSTNAME' 에 'Air' 포함)" >&2
    else
      echo "$HOME_PERSONA" > "$MACHINE_FILE"
      echo "⚠ 자동 매칭 실패 (hostname '$HOSTNAME') — 홈맥에어 default 사용" >&2
      echo "   다른 페르소나 원하면 $MACHINE_FILE 수동 편집" >&2
    fi
    exit 0
    ;;
  --other)
    [[ -f "$MACHINE_FILE" ]] || { echo "❌ $MACHINE_FILE 없음 — 'persona.sh --init' 먼저" >&2; exit 1; }
    current=$(jq -r '.persona' "$MACHINE_FILE")
    if [[ "$current" == "홈맥에어" ]]; then
      echo "회사맥프로"
    else
      echo "홈맥에어"
    fi
    ;;
  --json)
    [[ -f "$MACHINE_FILE" ]] || { echo "❌ $MACHINE_FILE 없음" >&2; exit 1; }
    cat "$MACHINE_FILE"
    ;;
  ""|--get)
    [[ -f "$MACHINE_FILE" ]] || { echo "❌ $MACHINE_FILE 없음 — 'persona.sh --init' 먼저" >&2; exit 1; }
    jq -r '.persona' "$MACHINE_FILE"
    ;;
  *)
    echo "사용법: persona.sh [--init|--json|--other]" >&2
    exit 1
    ;;
esac
```

권한:
```bash
chmod +x ~/.config/agent-harness-baseline/bin/persona.sh
```

- [ ] **Step 1.4: 테스트 통과 확인**

```bash
cd ~/.config/agent-harness-baseline && bats tests/persona.bats
# Expected: 7 tests, 0 failures
```

- [ ] **Step 1.5: 자기 머신에 .machine.json 생성**

```bash
~/.config/agent-harness-baseline/bin/persona.sh --init
# Expected: ✓ 홈맥에어 또는 ✓ 회사맥프로 메시지

cat ~/.config/agent-harness-baseline/.machine.json
# Expected: persona/emoji/color/label JSON
```

- [ ] **Step 1.6: .gitignore 검토**

`.machine.json` 은 머신별 다름 → git 추적 X. `.gitignore` 에 추가:

```bash
# 기존 .gitignore 끝에 추가
echo "" >> ~/.config/agent-harness-baseline/.gitignore
echo "# 머신 페르소나 (머신별 다름)" >> ~/.config/agent-harness-baseline/.gitignore
echo ".machine.json" >> ~/.config/agent-harness-baseline/.gitignore
```

- [ ] **Step 1.7: 커밋**

```bash
cd ~/.config/agent-harness-baseline
git add bin/persona.sh tests/persona.bats .gitignore
git commit -m "feat(persona): 머신 페르소나 helper

- bin/persona.sh: --init/--get/--json/--other
- hostname 자동 매칭 (Air → 홈맥에어, Pro → 회사맥프로)
- .machine.json 머신별 (gitignore)
- 7 bats tests"
```

---

## Task 2: ledger append (`bin/ledger-append.sh`)

**Files:**
- Create: `bin/ledger-append.sh`
- Create: `tests/ledger-append.bats`
- Create: `state/activity/.gitkeep`

**기능:**
- 인자: event type (필수) + key=value pairs (선택)
- 동작: 현재 페르소나의 `state/activity/{persona}.jsonl` 에 한 줄 append
- timestamp/host 자동 채움
- JSONL 한 줄 = 한 이벤트 (jq 호환)

**호출 예:**
```bash
ledger-append.sh session_end cwd=~/dev/lawblaw duration_min=22 commits=3
ledger-append.sh commit message="fix(auth): SSO" sha=abc123
ledger-append.sh wake
```

- [ ] **Step 2.1: 실패하는 테스트 작성**

Create `tests/ledger-append.bats`:

```bash
# tests/ledger-append.bats
load test_helper

setup_persona() {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
}

@test "ledger-append fails without event type" {
  setup_persona
  run "$SSOT/bin/ledger-append.sh"
  [ "$status" -ne 0 ]
}

@test "ledger-append creates jsonl file with single event" {
  setup_persona
  run "$SSOT/bin/ledger-append.sh" "session_start"
  [ "$status" -eq 0 ]
  ledger="$SSOT/state/activity/홈맥에어.jsonl"
  [ -f "$ledger" ]
  [ $(wc -l < "$ledger") -eq 1 ]
  type=$(jq -r '.type' "$ledger")
  [ "$type" = "session_start" ]
  host=$(jq -r '.host' "$ledger")
  [ "$host" = "홈맥에어" ]
}

@test "ledger-append parses key=value pairs into JSON fields" {
  setup_persona
  run "$SSOT/bin/ledger-append.sh" "session_end" \
    "cwd=/dev/lawblaw" "duration_min=22" "commits=3"
  [ "$status" -eq 0 ]
  ledger="$SSOT/state/activity/홈맥에어.jsonl"
  cwd=$(jq -r '.cwd' "$ledger")
  [ "$cwd" = "/dev/lawblaw" ]
  duration=$(jq -r '.duration_min' "$ledger")
  [ "$duration" = "22" ]
  commits=$(jq -r '.commits' "$ledger")
  [ "$commits" = "3" ]
}

@test "ledger-append appends (does not overwrite)" {
  setup_persona
  "$SSOT/bin/ledger-append.sh" "wake" >/dev/null
  "$SSOT/bin/ledger-append.sh" "session_start" >/dev/null
  "$SSOT/bin/ledger-append.sh" "session_end" "duration_min=10" >/dev/null
  ledger="$SSOT/state/activity/홈맥에어.jsonl"
  [ $(wc -l < "$ledger") -eq 3 ]
  third=$(sed -n '3p' "$ledger" | jq -r '.type')
  [ "$third" = "session_end" ]
}

@test "ledger-append timestamp is ISO8601" {
  setup_persona
  run "$SSOT/bin/ledger-append.sh" "wake"
  ledger="$SSOT/state/activity/홈맥에어.jsonl"
  ts=$(jq -r '.ts' "$ledger")
  # ISO8601 형식 검증 (YYYY-MM-DDTHH:MM:SS+/-HHMM)
  [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:?[0-9]{2}$ ]]
}

@test "ledger-append handles values with spaces (quoted)" {
  setup_persona
  run "$SSOT/bin/ledger-append.sh" "commit" "message=fix(auth): SSO 토큰 검증"
  [ "$status" -eq 0 ]
  ledger="$SSOT/state/activity/홈맥에어.jsonl"
  msg=$(jq -r '.message' "$ledger")
  [ "$msg" = "fix(auth): SSO 토큰 검증" ]
}
```

- [ ] **Step 2.2: 테스트 실패 확인**

```bash
cd ~/.config/agent-harness-baseline && bats tests/ledger-append.bats
# Expected: 6 tests, 6 failures
```

- [ ] **Step 2.3: ledger-append.sh 구현**

Create `bin/ledger-append.sh`:

```bash
#!/usr/bin/env bash
# ledger-append.sh — 활동 ledger에 한 줄 append
# 사용법:
#   ledger-append.sh <event_type> [key=value]...
# 예:
#   ledger-append.sh session_end cwd=/dev/x duration_min=22 commits=3

set -uo pipefail

SSOT="$HOME/.config/agent-harness-baseline"
PERSONA_BIN="$SSOT/bin/persona.sh"

if [[ $# -lt 1 ]]; then
  echo "사용법: ledger-append.sh <event_type> [key=value]..." >&2
  exit 1
fi

event_type="$1"
shift

persona=$("$PERSONA_BIN") || { echo "❌ persona 조회 실패" >&2; exit 1; }
ledger_dir="$SSOT/state/activity"
ledger_file="$ledger_dir/$persona.jsonl"
mkdir -p "$ledger_dir"

# 기본 필드 — ts (ISO8601 with timezone), host, type
ts=$(date +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')

# jq로 JSON 객체 빌드 (key=value 인자 → JSON 필드)
# 숫자 같은 값은 jq가 자동 number 인식
json=$(jq -nc \
  --arg ts "$ts" \
  --arg host "$persona" \
  --arg type "$event_type" \
  '{ts:$ts, host:$host, type:$type}')

for pair in "$@"; do
  if [[ "$pair" == *"="* ]]; then
    key="${pair%%=*}"
    value="${pair#*=}"
    # 숫자면 number, 아니면 string
    if [[ "$value" =~ ^-?[0-9]+$ ]]; then
      json=$(echo "$json" | jq -c --arg k "$key" --argjson v "$value" '. + {($k): $v}')
    else
      json=$(echo "$json" | jq -c --arg k "$key" --arg v "$value" '. + {($k): $v}')
    fi
  fi
done

echo "$json" >> "$ledger_file"
```

권한:
```bash
chmod +x ~/.config/agent-harness-baseline/bin/ledger-append.sh
```

- [ ] **Step 2.4: 테스트 통과 확인**

```bash
cd ~/.config/agent-harness-baseline && bats tests/ledger-append.bats
# Expected: 6 tests, 0 failures
```

- [ ] **Step 2.5: state/activity 디렉터리 git 추적**

```bash
mkdir -p ~/.config/agent-harness-baseline/state/activity
touch ~/.config/agent-harness-baseline/state/activity/.gitkeep
```

- [ ] **Step 2.6: 커밋**

```bash
cd ~/.config/agent-harness-baseline
git add bin/ledger-append.sh tests/ledger-append.bats state/activity/.gitkeep
git commit -m "feat(ledger): 활동 ledger append helper

- bin/ledger-append.sh: event_type + key=value pairs → JSONL append
- ts 자동 (ISO8601 with TZ), host 자동 (현재 페르소나)
- 숫자 자동 인식 (number vs string)
- state/activity/.gitkeep
- 6 bats tests"
```

---

## Task 3: ledger query (`bin/ledger-query.sh`)

**Files:**
- Create: `bin/ledger-query.sh`
- Create: `tests/ledger-query.bats`

**기능:**
- 양 머신 ledger 파일 합쳐 시간순 sort
- 필터: `--type`, `--persona`, `--since`, `--cwd`
- 출력: JSONL (default) 또는 `--format=text` (사람용)

**호출 예:**
```bash
ledger-query.sh                                    # 모든 이벤트 (시간순)
ledger-query.sh --type session_end                 # 세션 종료만
ledger-query.sh --persona 회사맥프로                 # 특정 머신만
ledger-query.sh --since 7d                         # 최근 7일
ledger-query.sh --since 4h --type session_end      # 4시간 이내 세션 종료
ledger-query.sh --format=text                      # 사람 친화 출력
```

- [ ] **Step 3.1: 실패하는 테스트 작성**

Create `tests/ledger-query.bats`:

```bash
# tests/ledger-query.bats
load test_helper

setup_two_ledgers() {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"

  # 동적 ts 생성 (테스트 실행 시각 기준 — 시기 민감 회피)
  # 모두 4시간 초과 과거 (since 4h 필터 밖이어야)
  TS_OLDEST=$(date -v-25H +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  TS_OLD=$(date -v-20H +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  TS_MID=$(date -v-12H +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  TS_RECENT=$(date -v-8H +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  export TS_OLDEST TS_OLD TS_MID TS_RECENT

  cat > "$SSOT/state/activity/홈맥에어.jsonl" <<EOF
{"ts":"$TS_OLDEST","host":"홈맥에어","type":"session_end","cwd":"/dev/foo","duration_min":15}
{"ts":"$TS_RECENT","host":"홈맥에어","type":"session_end","cwd":"/dev/lawblaw","duration_min":22}
EOF
  cat > "$SSOT/state/activity/회사맥프로.jsonl" <<EOF
{"ts":"$TS_OLD","host":"회사맥프로","type":"session_end","cwd":"/dev/lawblaw","duration_min":72}
{"ts":"$TS_MID","host":"회사맥프로","type":"commit","sha":"abc123"}
EOF
}

@test "ledger-query (no args) returns all events sorted by ts ascending" {
  setup_two_ledgers
  run "$SSOT/bin/ledger-query.sh"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | wc -l | tr -d ' ')
  [ "$count" = "4" ]
  # 첫 줄 = 가장 오래된 (TS_OLDEST = 25h 전)
  first_ts=$(echo "$output" | head -1 | jq -r '.ts')
  [ "$first_ts" = "$TS_OLDEST" ]
}

@test "ledger-query --type filters by event type" {
  setup_two_ledgers
  run "$SSOT/bin/ledger-query.sh" --type session_end
  [ "$status" -eq 0 ]
  count=$(echo "$output" | wc -l | tr -d ' ')
  [ "$count" = "3" ]
}

@test "ledger-query --persona filters by host" {
  setup_two_ledgers
  run "$SSOT/bin/ledger-query.sh" --persona 회사맥프로
  [ "$status" -eq 0 ]
  count=$(echo "$output" | wc -l | tr -d ' ')
  [ "$count" = "2" ]
  # 모두 회사맥프로
  hosts=$(echo "$output" | jq -r '.host' | sort -u)
  [ "$hosts" = "회사맥프로" ]
}

@test "ledger-query --since 4h filters recent events" {
  setup_two_ledgers
  # 현재 시각 기준 1시간 전 이벤트 추가
  ts=$(date -v-1H +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  echo "{\"ts\":\"$ts\",\"host\":\"홈맥에어\",\"type\":\"wake\"}" >> "$SSOT/state/activity/홈맥에어.jsonl"
  run "$SSOT/bin/ledger-query.sh" --since 4h
  [ "$status" -eq 0 ]
  # wake 이벤트만 매칭 (다른 건 어제/오늘 이른 시각)
  count=$(echo "$output" | wc -l | tr -d ' ')
  [ "$count" = "1" ]
  type=$(echo "$output" | jq -r '.type')
  [ "$type" = "wake" ]
}

@test "ledger-query handles missing ledger files gracefully" {
  # 빈 상태에서 호출
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  run "$SSOT/bin/ledger-query.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "ledger-query --format=text outputs human-readable lines" {
  setup_two_ledgers
  run "$SSOT/bin/ledger-query.sh" --format=text
  [ "$status" -eq 0 ]
  # 첫 줄에 페르소나 이름 포함
  [[ "$output" == *"홈맥에어"* ]]
  [[ "$output" == *"회사맥프로"* ]]
}
```

- [ ] **Step 3.2: 테스트 실패 확인**

```bash
cd ~/.config/agent-harness-baseline && bats tests/ledger-query.bats
# Expected: 6 tests, 6 failures
```

- [ ] **Step 3.3: ledger-query.sh 구현**

Create `bin/ledger-query.sh`:

```bash
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

# jq 필터 빌드
jq_filter='.'
[[ -n "$filter_type" ]]    && jq_filter+=" | select(.type == \"$filter_type\")"
[[ -n "$filter_persona" ]] && jq_filter+=" | select(.host == \"$filter_persona\")"
[[ -n "$since_ts" ]]       && jq_filter+=" | select(.ts >= \"$since_ts\")"

# 시간순 sort 후 필터
sorted=$(echo "$all_events" | jq -c "select(.ts != null)" | jq -s -c 'sort_by(.ts) | .[]' | jq -c "$jq_filter")

if [[ "$format" == "text" ]]; then
  # 사람 친화 형식
  echo "$sorted" | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "$line" | jq -r '"\(.ts) · \(.host) · \(.type)\(if .cwd then " · \(.cwd)" else "" end)\(if .duration_min then " · \(.duration_min)m" else "" end)"'
  done
else
  echo "$sorted"
fi
```

권한:
```bash
chmod +x ~/.config/agent-harness-baseline/bin/ledger-query.sh
```

- [ ] **Step 3.4: 테스트 통과 확인**

```bash
cd ~/.config/agent-harness-baseline && bats tests/ledger-query.bats
# Expected: 6 tests, 0 failures
```

- [ ] **Step 3.5: 커밋**

```bash
cd ~/.config/agent-harness-baseline
git add bin/ledger-query.sh tests/ledger-query.bats
git commit -m "feat(ledger): 양 머신 ledger 통합 query

- bin/ledger-query.sh: --type/--persona/--since/--format
- 양쪽 jsonl 합쳐 시간순 sort
- 빈 ledger 우아한 처리
- 6 bats tests"
```

---

## Task 4: 즉시 push 모드 (`bin/sync.sh --immediate`)

**Files:**
- Modify: `bin/sync.sh` (--immediate flag 추가)
- Create: `tests/sync-immediate.bats`

**기능:**
- 기존 sync.sh: pull → 변경 있으면 commit/push
- 새 모드 `--immediate`: pull skip, 변경 있으면 commit/push만 (백그라운드 실행 의도)
- 사용 시나리오: Stop hook이 ledger append 후 호출 → 다른 머신 30초 이내 도착

- [ ] **Step 4.1: 실패하는 테스트 작성**

Create `tests/sync-immediate.bats`:

```bash
# tests/sync-immediate.bats
load test_helper

setup_git_repo() {
  cd "$SSOT"
  git init -q
  git config user.email "test@test"
  git config user.name "test"
  git commit --allow-empty -m "init" -q
}

@test "sync.sh --immediate flag is recognized" {
  setup_git_repo
  run "$SSOT/bin/sync.sh" --immediate
  # 원격 없음으로 exit 0 (skip)
  [ "$status" -eq 0 ]
}

@test "sync.sh --immediate skips pull (no remote needed)" {
  setup_git_repo
  # 변경 만들기
  echo "test" > "$SSOT/test.txt"
  # remote 없으니 push도 skip — exit 0
  run "$SSOT/bin/sync.sh" --immediate
  [ "$status" -eq 0 ]
  # 변경은 commit 됐어야
  cd "$SSOT"
  status_count=$(git status --porcelain | wc -l | tr -d ' ')
  [ "$status_count" = "0" ]
}

@test "sync.sh (no flag) keeps original pull behavior" {
  setup_git_repo
  # 원격 없으니 exit 0 (skip)
  run "$SSOT/bin/sync.sh"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 4.2: 테스트 실패 확인**

```bash
cd ~/.config/agent-harness-baseline && bats tests/sync-immediate.bats
# Expected: 3 tests, 일부 실패 (--immediate flag 미인식)
```

- [ ] **Step 4.3: sync.sh 수정**

기존 `bin/sync.sh` 를 다음으로 교체:

```bash
#!/usr/bin/env bash
# sync.sh — git pull → 변경 있으면 자동 commit/push
# 사용법:
#   sync.sh                기본 (pull → commit → push)
#   sync.sh --immediate    pull 스킵, commit/push만 (Stop hook 등에서 호출)
set -uo pipefail

SSOT="$HOME/.config/agent-harness-baseline"
cd "$SSOT" || exit 1

mode="${1:-full}"

# 원격 없으면 스킵
git remote get-url origin >/dev/null 2>&1 || exit 0

BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo main)

if [[ "$mode" != "--immediate" ]]; then
  # full mode: pull 먼저
  git fetch --quiet origin "$BRANCH" 2>&1 || exit 1
  git pull --rebase --autostash --quiet origin "$BRANCH" 2>&1 || exit 1

  # pull 로 rules/MEMORY 변경이 들어왔다면 ~/AGENTS.md 갱신
  "$SSOT/bin/rebuild-agents-md.sh" --quiet 2>/dev/null || true
fi

# Push 할 변경 있는지 (양 모드 공통)
if [[ -n "$(git status --porcelain)" ]]; then
  git add .
  git commit -m "auto: $(hostname -s) $(date +%FT%T%z)" --quiet
  git push --quiet 2>&1 || true   # push 실패해도 commit 은 살림
fi
```

- [ ] **Step 4.4: 테스트 통과 확인**

```bash
cd ~/.config/agent-harness-baseline && bats tests/sync-immediate.bats
# Expected: 3 tests, 0 failures
```

- [ ] **Step 4.5: 회귀 테스트 — 기존 doctor + 다른 테스트 모두 통과**

```bash
cd ~/.config/agent-harness-baseline && bats tests/
# Expected: 모든 task의 모든 테스트 통과
```

- [ ] **Step 4.6: 커밋**

```bash
cd ~/.config/agent-harness-baseline
git add bin/sync.sh tests/sync-immediate.bats
git commit -m "feat(sync): --immediate 모드 추가

- pull 스킵, commit/push만
- Stop hook 등에서 백그라운드 호출 의도
- 다른 맥북 latency 30분 → ~30초
- 3 bats tests + 회귀 테스트"
```

---

## Task 5: 통합 helper (`bin/notify-activity.sh`)

**Files:**
- Create: `bin/notify-activity.sh`
- Create: `tests/notify-activity.bats`

**기능:**
- 한 호출로 3채널 동시 발사:
  1. ledger.jsonl append (`bin/ledger-append.sh` 위임)
  2. Telegram push (settings.local.json 의 토큰 활용, 실패 무시)
  3. git push 백그라운드 (`bin/sync.sh --immediate &`)
- 인터페이스: `notify-activity.sh <event_type> [key=value]...`
- Telegram 메시지 포맷: 페르소나 이모지 + 헤드라인

- [ ] **Step 5.1: 실패하는 테스트 작성**

Create `tests/notify-activity.bats`:

```bash
# tests/notify-activity.bats
load test_helper

setup_persona() {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
}

@test "notify-activity calls ledger-append (event in jsonl)" {
  setup_persona
  # Telegram 토큰 없음 + git remote 없음 → 그쪽은 silent fail OK
  run "$SSOT/bin/notify-activity.sh" "session_start" "cwd=/x"
  [ "$status" -eq 0 ]
  ledger="$SSOT/state/activity/홈맥에어.jsonl"
  [ -f "$ledger" ]
  type=$(jq -r '.type' "$ledger")
  [ "$type" = "session_start" ]
}

@test "notify-activity does not fail when telegram token missing" {
  setup_persona
  # ~/.claude/settings.local.json 없음
  run "$SSOT/bin/notify-activity.sh" "wake"
  [ "$status" -eq 0 ]
}

@test "notify-activity formats Telegram message with persona emoji" {
  setup_persona
  # mock telegram (Bash function override)
  # 실제 push는 없지만 메시지 포맷 함수 단위 테스트
  source "$SSOT/bin/notify-activity.sh" --source-only 2>/dev/null || skip "--source-only 미지원이면 skip"
  msg=$(format_telegram_message "session_end" "lawblaw_dev" "22m" "3 commits")
  [[ "$msg" == *"🏠"* ]]
  [[ "$msg" == *"홈맥에어"* ]]
  [[ "$msg" == *"lawblaw_dev"* ]]
}

@test "notify-activity is idempotent in dry-run" {
  setup_persona
  DRY_RUN=1 run "$SSOT/bin/notify-activity.sh" "wake"
  [ "$status" -eq 0 ]
  ledger="$SSOT/state/activity/홈맥에어.jsonl"
  # dry run 이면 ledger 도 안 적힘
  [ ! -f "$ledger" ]
}
```

- [ ] **Step 5.2: 테스트 실패 확인**

```bash
cd ~/.config/agent-harness-baseline && bats tests/notify-activity.bats
# Expected: 4 tests 실패
```

- [ ] **Step 5.3: notify-activity.sh 구현**

Create `bin/notify-activity.sh`:

```bash
#!/usr/bin/env bash
# notify-activity.sh — 활동 발생 시 3채널 동시 발사
#   1. ledger.jsonl append
#   2. Telegram push (best effort)
#   3. git push --immediate (백그라운드)
#
# 사용법:
#   notify-activity.sh <event_type> [key=value]...
# 예:
#   notify-activity.sh session_end cwd=/dev/lawblaw duration_min=22 commits=3
#
# 환경 변수:
#   DRY_RUN=1   3채널 모두 skip (테스트용)

set -uo pipefail

SSOT="$HOME/.config/agent-harness-baseline"
LEDGER_BIN="$SSOT/bin/ledger-append.sh"
SYNC_BIN="$SSOT/bin/sync.sh"
PERSONA_BIN="$SSOT/bin/persona.sh"
SETTINGS="$HOME/.claude/settings.local.json"

# Telegram 메시지 포맷 (단위 테스트용 함수)
format_telegram_message() {
  local event="$1" cwd="${2:-}" duration="${3:-}" commits="${4:-}"
  local persona_json
  persona_json=$("$PERSONA_BIN" --json 2>/dev/null) || return 1
  local persona emoji
  persona=$(echo "$persona_json" | jq -r '.persona')
  emoji=$(echo "$persona_json" | jq -r '.emoji')

  case "$event" in
    session_end)
      printf "%s *%s* · 작업 끝\n📂 %s\n⏱ %s · 📝 %s" \
        "$emoji" "$persona" "$cwd" "$duration" "$commits"
      ;;
    session_start)
      printf "%s *%s* · 시작\n📂 %s" "$emoji" "$persona" "$cwd"
      ;;
    *)
      printf "%s *%s* · %s" "$emoji" "$persona" "$event"
      ;;
  esac
}

send_telegram() {
  local text="$1"
  [[ -f "$SETTINGS" ]] || return 0
  local token chat_id
  token=$(jq -r '.env.TELEGRAM_TOKEN // empty' "$SETTINGS" 2>/dev/null)
  chat_id=$(jq -r '.env.TELEGRAM_CHAT_ID // empty' "$SETTINGS" 2>/dev/null)
  [[ -n "$token" && -n "$chat_id" ]] || return 0
  curl -sS -X POST "https://api.telegram.org/bot${token}/sendMessage" \
    -d "chat_id=${chat_id}" \
    -d "text=${text}" \
    -d "parse_mode=Markdown" \
    >/dev/null 2>&1 || true
}

# --source-only 모드 (테스트가 함수만 가져올 때)
if [[ "${1:-}" == "--source-only" ]]; then
  return 0 2>/dev/null || exit 0
fi

if [[ $# -lt 1 ]]; then
  echo "사용법: notify-activity.sh <event_type> [key=value]..." >&2
  exit 1
fi

event_type="$1"
shift

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  exit 0
fi

# (1) ledger append
"$LEDGER_BIN" "$event_type" "$@" || true

# (2) Telegram push (key=value 추출해서 헤드라인 합성)
cwd="" duration="" commits=""
for pair in "$@"; do
  case "$pair" in
    cwd=*)          cwd="${pair#cwd=}" ;;
    duration_min=*) duration="${pair#duration_min=}m" ;;
    commits=*)      commits="${pair#commits=}" ;;
  esac
done
text=$(format_telegram_message "$event_type" "$cwd" "$duration" "$commits")
send_telegram "$text"

# (3) git push --immediate (백그라운드)
"$SYNC_BIN" --immediate >/dev/null 2>&1 &
disown 2>/dev/null || true
```

권한:
```bash
chmod +x ~/.config/agent-harness-baseline/bin/notify-activity.sh
```

- [ ] **Step 5.4: 테스트 통과 확인**

```bash
cd ~/.config/agent-harness-baseline && bats tests/notify-activity.bats
# Expected: 4 tests, 0 failures
```

- [ ] **Step 5.5: 실제 양 머신 통합 테스트 (manual, 자기 PC)**

```bash
# 자기 머신에서 실제 호출
~/.config/agent-harness-baseline/bin/notify-activity.sh "wake"

# 검증:
# 1. ledger 추가
cat ~/.config/agent-harness-baseline/state/activity/홈맥에어.jsonl | tail -1
# Expected: 마지막 줄이 type=wake

# 2. Telegram 도착 확인 (휴대폰)
# Expected: "🏠 홈맥에어 · wake" 메시지

# 3. git push 백그라운드 실행 확인
sleep 3
cd ~/.config/agent-harness-baseline && git log --oneline -1
# Expected: "auto: ..." 자동 커밋
```

- [ ] **Step 5.6: 커밋**

```bash
cd ~/.config/agent-harness-baseline
git add bin/notify-activity.sh tests/notify-activity.bats
git commit -m "feat(activity): 3채널 동시 발사 helper

- bin/notify-activity.sh: ledger + Telegram + git push --immediate
- 페르소나 이모지/이름 자동 메시지 포맷
- DRY_RUN=1 환경변수 (테스트용)
- Telegram 토큰 없어도 silent skip
- 4 bats tests + 자기 PC 실측 통과"
```

---

## Task 6: doctor 검증 + Phase 1 통합 확인

**Files:**
- Modify: `bin/doctor.sh` (Phase 1 검증 항목 추가)

**기능:**
- 페르소나/ledger/sync immediate 모드 검증을 doctor 에 추가
- 회사 맥북에서 부트스트랩 후 한 번 돌리면 Phase 1 인프라 정상 확인 가능

- [ ] **Step 6.1: doctor.sh 에 검증 섹션 추가**

`bin/doctor.sh` 의 마지막 섹션 (`echo ""; [[ $errors ...]]`) **직전**에 다음 추가:

```bash
echo ""
echo "── Phase 1: 두 맥북 살아있음 인프라 ──"

# 페르소나
if [[ -f "$SSOT/.machine.json" ]]; then
  persona=$(jq -r '.persona' "$SSOT/.machine.json" 2>/dev/null)
  emoji=$(jq -r '.emoji' "$SSOT/.machine.json" 2>/dev/null)
  echo "✓ 페르소나: $emoji $persona"
else
  echo "❌ .machine.json 없음 — 'bin/persona.sh --init' 실행"; ((errors++))
fi

# 활동 ledger
if [[ -d "$SSOT/state/activity" ]]; then
  ledger_count=$(ls "$SSOT/state/activity"/*.jsonl 2>/dev/null | wc -l | tr -d ' ')
  echo "✓ state/activity ($ledger_count ledger 파일)"
else
  echo "❌ state/activity/ 없음"; ((errors++))
fi

# helper 실행 권한
for s in bin/persona.sh bin/ledger-append.sh bin/ledger-query.sh bin/notify-activity.sh; do
  if [[ -x "$SSOT/$s" ]]; then
    echo "✓ $s"
  else
    echo "❌ $s 실행 권한/존재 X"; ((errors++))
  fi
done

# sync immediate 모드 인식
if grep -q -- "--immediate" "$SSOT/bin/sync.sh" 2>/dev/null; then
  echo "✓ sync.sh --immediate 모드 지원"
else
  echo "❌ sync.sh --immediate 미지원"; ((errors++))
fi

# bats 설치
if command -v bats >/dev/null; then
  echo "✓ bats $(bats --version | awk '{print $2}')"
else
  echo "⚠ bats 미설치 — 'brew install bats-core' (테스트 환경)"
fi
```

- [ ] **Step 6.2: doctor 실행 → 통과**

```bash
~/.config/agent-harness-baseline/bin/doctor.sh
# Expected: 새 섹션의 모든 ✓, 0 errors
```

- [ ] **Step 6.3: 모든 bats 테스트 회귀 확인**

```bash
~/.config/agent-harness-baseline/bin/test.sh
# Expected: 모든 task의 모든 테스트 통과 (0 failures)
```

- [ ] **Step 6.4: 양 머신 sync latency 실측 (manual, 회사 맥북 받았을 때)**

회사 맥북에서:
```bash
# 1. 회사 맥북에서 활동 발생
~/.config/agent-harness-baseline/bin/notify-activity.sh "wake"

# 2. 개인 맥북에서 (다른 셸):
sleep 30
cd ~/.config/agent-harness-baseline && git pull --quiet
cat state/activity/회사맥프로.jsonl | tail -1
# Expected: 30초 이내 wake 이벤트 도착
```

이 step은 회사 맥북 받기 전엔 self-test 어렵 — 자기 PC 안에서 git remote 사용한 sanity check만 충분.

- [ ] **Step 6.5: Phase 1 마무리 커밋**

```bash
cd ~/.config/agent-harness-baseline
git add bin/doctor.sh
git commit -m "chore(doctor): Phase 1 인프라 검증 추가

- 페르소나, ledger 디렉터리, helper 실행 권한
- sync --immediate 모드, bats 설치 확인

Phase 1 완료. 다음: Phase 2 plan 작성 후 C2 (HUD) + C3 (Stop hook + catchup)."
```

---

## Phase 1 완료 검증 체크리스트

이 plan 끝나면 다음이 모두 동작해야:

- [ ] `bin/persona.sh --init` 으로 `.machine.json` 자동 생성
- [ ] `bin/persona.sh` / `--json` / `--other` 정상 출력
- [ ] `bin/ledger-append.sh session_end cwd=X duration_min=22` → JSONL 1줄 추가
- [ ] `bin/ledger-query.sh --since 7d --type session_end` 로 양 머신 합쳐 시간순 출력
- [ ] `bin/sync.sh --immediate` 가 pull 안 하고 commit/push만
- [ ] `bin/notify-activity.sh wake` 호출로 ledger + Telegram + git push 모두 발동
- [ ] `bin/doctor.sh` 에 Phase 1 섹션 ✓ 표시
- [ ] `bin/test.sh` 로 모든 bats 테스트 통과 (총 ~26 tests)
- [ ] git log 에 6개 커밋 (Task 0~6)

## 다음 Phase

이 인프라가 안정되면 Phase 2 plan 별도 작성:
- **C2** HUD (`bin/hud-machines.sh` + `omc-hud.mjs` segment + zsh RPROMPT + `hudm` alias)
- **C3** 세션 끝 알림 (`bin/notify-session-end.sh` + Stop hook + `bin/hud-catchup.sh` + 일일 요약 launchd)

Phase 2 plan 은 `docs/superpowers/plans/2026-04-29-dual-mac-presence-phase-2.md` 로.
