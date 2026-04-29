# 두 맥북 살아있음 시스템 — Phase 3 (셋업 라이브 중계 + 첫 인사 모먼트) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Phase 1+2 인프라 위에 새 맥북 셋업의 와우 모먼트 두 가지 — 부트스트랩 라이브 중계(폰에 1메시지가 13단계 progress) + 첫 셸 진입 시 1회 핸드셰이크 애니메이션 + 컨텍스트 핸드오프.

**Architecture:** Telegram bot의 `editMessageText` API로 한 메시지가 살아 움직임. 메시지 ID는 `state/wizard-message-id.txt` 에 보존(중간 멈춰도 재개). 첫 인사는 `mac-setup` 완료 마커 + zsh `precmd` 1회 발동 패턴. 모든 외부 자산(mac-setup.sh, bootstrap-new-mac.sh) 변경은 1줄 hook 추가로 최소화.

**Tech Stack:** bash 3.2+, zsh, jq, bats-core, curl (Telegram), Phase 1+2 helpers (persona, ledger, notify-activity)

**Pre-conditions:**
- Phase 1+2 main에 머지 (커밋 `40afa8d`)
- branch `feature/dual-mac-phase-3` (이미 분기됨)
- `~/.claude/settings.local.json` 에 `TELEGRAM_TOKEN`/`TELEGRAM_CHAT_ID` (없으면 silent skip)
- 다른 에이전트가 `bin/mac-setup.sh`, `bootstrap/bootstrap-new-mac.sh`, `state/wizard-state.json`, `shell/ui-lib.sh` 자산 보유 — 최소 침범

---

## File Structure

```
bin/
├── notify-step.sh       (Task 1)  Telegram editMessageText — 13단계 라이브
├── greet.sh             (Task 5)  핸드셰이크 + 환영 배너 + 컨텍스트
└── doctor.sh            (Task 7)  Phase 3 섹션 추가

shell/
└── zshrc.shared         (Task 6)  __maybe_greet precmd hook

bin/mac-setup.sh         (Task 2)  step 함수에 notify-step 호출 추가 (1줄)
bootstrap/bootstrap-new-mac.sh (Task 3)  동일 (1줄)

state/
├── wizard-message-id.txt  (Task 1) Telegram message ID 보존 (gitignored)
└── wizard-state.json      (Task 6) greeted 필드 추가 (이미 존재)

tests/
├── notify-step.bats        (Task 1)
└── greet.bats              (Task 5)
```

총 7 tasks, ~25 bats tests, ~40 steps.

---

## Task 1: notify-step.sh — Telegram editMessageText 라이브 진행

**Files:**
- Create: `bin/notify-step.sh`
- Create: `tests/notify-step.bats`

**기능:**
- 첫 호출: Telegram `sendMessage` → message_id 저장
- 이후 호출: `editMessageText` 로 같은 메시지 갱신
- 사용법:
  ```
  notify-step.sh start <total>              # 첫 호출, 시작 메시지
  notify-step.sh update <current> <total> <status_emoji> <step_name>
  notify-step.sh done <total>               # 완료 메시지
  notify-step.sh human-action <step_name> <action_text>  # 별도 메시지
  notify-step.sh reset                      # message_id 리셋
  ```
- 토큰 없으면 silent skip
- DRY_RUN=1 → 모든 외부 호출 skip

- [ ] **Step 1.1: 실패 테스트 작성**

Create `tests/notify-step.bats`:

```bash
load test_helper

setup_persona() {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
}

@test "notify-step start saves message_id from telegram (mocked)" {
  setup_persona
  # Telegram 토큰 없으면 silent skip — message_id 안 만듦
  DRY_RUN=1 run "$SSOT/bin/notify-step.sh" start 13
  [ "$status" -eq 0 ]
  # DRY_RUN 시 message_id 파일 안 만듦
  [ ! -f "$SSOT/state/wizard-message-id.txt" ]
}

@test "notify-step build-message format includes progress bar" {
  setup_persona
  source "$SSOT/bin/notify-step.sh" --source-only 2>/dev/null || skip
  msg=$(build_progress_message 4 13 "🔄" "공유 자산 통합" "12분 경과")
  [[ "$msg" == *"4/13"* ]]
  [[ "$msg" == *"31%"* ]]
  [[ "$msg" == *"▓"* ]]
  [[ "$msg" == *"공유 자산 통합"* ]]
}

@test "notify-step build-message progress bar = 13 chars" {
  setup_persona
  source "$SSOT/bin/notify-step.sh" --source-only 2>/dev/null || skip
  bar=$(build_progress_bar 4 13)
  # ▓ + ░ 합쳐 13 chars
  count=$(printf "%s" "$bar" | grep -o '[▓░]' | wc -l | tr -d ' ')
  [ "$count" = "13" ]
}

@test "notify-step done message changes header to completion" {
  setup_persona
  source "$SSOT/bin/notify-step.sh" --source-only 2>/dev/null || skip
  msg=$(build_done_message 13 "24분")
  [[ "$msg" == *"완료"* ]] || [[ "$msg" == *"🎉"* ]]
  [[ "$msg" == *"100%"* ]] || [[ "$msg" == *"13/13"* ]]
}

@test "notify-step human-action emits separate message text" {
  setup_persona
  source "$SSOT/bin/notify-step.sh" --source-only 2>/dev/null || skip
  msg=$(build_human_action_message "1Password CLI" "데스크톱 앱 → 설정 → CLI integration ON")
  [[ "$msg" == *"손이 필요해"* ]]
  [[ "$msg" == *"1Password CLI"* ]]
}

@test "notify-step reset removes message_id file" {
  setup_persona
  echo "12345" > "$SSOT/state/wizard-message-id.txt"
  run "$SSOT/bin/notify-step.sh" reset
  [ "$status" -eq 0 ]
  [ ! -f "$SSOT/state/wizard-message-id.txt" ]
}
```

- [ ] **Step 1.2: 테스트 실패 확인**

```bash
cd ~/.config/claude-sync && bats tests/notify-step.bats
# Expected: 6 tests, 6 failures
```

- [ ] **Step 1.3: bin/notify-step.sh 구현**

Create `bin/notify-step.sh`:

```bash
#!/usr/bin/env bash
# notify-step.sh — Telegram editMessageText 라이브 progress
# 사용법:
#   notify-step.sh start <total>
#   notify-step.sh update <current> <total> <status_emoji> <step_name>
#   notify-step.sh done <total>
#   notify-step.sh human-action <step_name> <action_text>
#   notify-step.sh reset
#
# 환경:
#   DRY_RUN=1   외부 호출 skip
#
# 메시지 ID 보존: state/wizard-message-id.txt

set -uo pipefail

SSOT="$HOME/.config/claude-sync"
PERSONA_BIN="$SSOT/bin/persona.sh"
SETTINGS="$HOME/.claude/settings.local.json"
MSG_ID_FILE="$SSOT/state/wizard-message-id.txt"

# Progress bar (▓▓▓▓░░░░░░░░░ 패턴, 13 chars)
build_progress_bar() {
  local current="$1" total="$2"
  local filled=$(( current * 13 / total ))
  (( filled > 13 )) && filled=13
  (( filled < 0 )) && filled=0
  local empty=$(( 13 - filled ))
  local bar=""
  local i
  for ((i=0; i<filled; i++)); do bar+="▓"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  printf "%s" "$bar"
}

# 진행 중 메시지 (페르소나 + 진행률 + 단계명)
build_progress_message() {
  local current="$1" total="$2" status="$3" step_name="$4" elapsed="${5:-}"
  local persona_json
  persona_json=$("$PERSONA_BIN" --json 2>/dev/null) || return 1
  local persona emoji
  persona=$(echo "$persona_json" | jq -r '.persona')
  emoji=$(echo "$persona_json" | jq -r '.emoji')

  local pct=$(( current * 100 / total ))
  local bar
  bar=$(build_progress_bar "$current" "$total")

  printf "%s %s 셋업 중...\n\n%s %d/%d · %d%%\n\n%s %s\n%s" \
    "$emoji" "$persona" \
    "$bar" "$current" "$total" "$pct" \
    "$status" "$step_name" \
    "${elapsed:+⏱ $elapsed}"
}

# 완료 메시지
build_done_message() {
  local total="$1" elapsed="${2:-}"
  local persona_json
  persona_json=$("$PERSONA_BIN" --json 2>/dev/null) || return 1
  local persona emoji
  persona=$(echo "$persona_json" | jq -r '.persona')
  emoji=$(echo "$persona_json" | jq -r '.emoji')

  local bar
  bar=$(build_progress_bar "$total" "$total")
  printf "🎉 %s %s 셋업 완료!\n\n%s %d/%d · 100%%\n\n%s\n\n🚀 다음: cs-doctor" \
    "$emoji" "$persona" \
    "$bar" "$total" "$total" \
    "${elapsed:+⏱ $elapsed}"
}

# 사람 액션 별도 메시지
build_human_action_message() {
  local step_name="$1" action_text="$2"
  printf "🔐 너의 손이 필요해\n\n[%s]\n\n%s" "$step_name" "$action_text"
}

# Telegram sendMessage (반환: message_id)
telegram_send() {
  local text="$1"
  [[ -f "$SETTINGS" ]] || return 0
  local token chat_id
  token=$(jq -r '.env.TELEGRAM_TOKEN // empty' "$SETTINGS" 2>/dev/null)
  chat_id=$(jq -r '.env.TELEGRAM_CHAT_ID // empty' "$SETTINGS" 2>/dev/null)
  [[ -n "$token" && -n "$chat_id" ]] || return 0
  local response
  response=$(curl -sS -X POST "https://api.telegram.org/bot${token}/sendMessage" \
    --max-time 5 \
    --data-urlencode "chat_id=${chat_id}" \
    --data-urlencode "text=${text}" \
    2>/dev/null) || return 0
  echo "$response" | jq -r '.result.message_id // empty' 2>/dev/null
}

# Telegram editMessageText
telegram_edit() {
  local message_id="$1" text="$2"
  [[ -f "$SETTINGS" ]] || return 0
  local token chat_id
  token=$(jq -r '.env.TELEGRAM_TOKEN // empty' "$SETTINGS" 2>/dev/null)
  chat_id=$(jq -r '.env.TELEGRAM_CHAT_ID // empty' "$SETTINGS" 2>/dev/null)
  [[ -n "$token" && -n "$chat_id" && -n "$message_id" ]] || return 0
  curl -sS -X POST "https://api.telegram.org/bot${token}/editMessageText" \
    --max-time 5 \
    --data-urlencode "chat_id=${chat_id}" \
    --data-urlencode "message_id=${message_id}" \
    --data-urlencode "text=${text}" \
    >/dev/null 2>&1 || true
}

# --source-only 모드 (테스트가 함수만 가져올 때)
if [[ "${1:-}" == "--source-only" ]]; then
  return 0 2>/dev/null || exit 0
fi

[[ "${DRY_RUN:-0}" == "1" ]] && exit 0

mkdir -p "$(dirname "$MSG_ID_FILE")"

case "${1:-}" in
  start)
    total="${2:-13}"
    text=$(build_progress_message 0 "$total" "⏳" "시작 중..." "")
    msg_id=$(telegram_send "$text")
    [[ -n "$msg_id" ]] && echo "$msg_id" > "$MSG_ID_FILE"
    ;;
  update)
    current="${2:-0}"
    total="${3:-13}"
    status="${4:-🔄}"
    step_name="${5:-}"
    elapsed="${6:-}"
    msg_id=""
    [[ -f "$MSG_ID_FILE" ]] && msg_id=$(cat "$MSG_ID_FILE")
    text=$(build_progress_message "$current" "$total" "$status" "$step_name" "$elapsed")
    if [[ -n "$msg_id" ]]; then
      telegram_edit "$msg_id" "$text"
    else
      # 첫 호출이면 sendMessage 후 ID 저장
      msg_id=$(telegram_send "$text")
      [[ -n "$msg_id" ]] && echo "$msg_id" > "$MSG_ID_FILE"
    fi
    ;;
  done)
    total="${2:-13}"
    elapsed="${3:-}"
    msg_id=""
    [[ -f "$MSG_ID_FILE" ]] && msg_id=$(cat "$MSG_ID_FILE")
    text=$(build_done_message "$total" "$elapsed")
    if [[ -n "$msg_id" ]]; then
      telegram_edit "$msg_id" "$text"
    else
      telegram_send "$text" >/dev/null
    fi
    ;;
  human-action)
    step_name="${2:-?}"
    action_text="${3:-}"
    text=$(build_human_action_message "$step_name" "$action_text")
    telegram_send "$text" >/dev/null
    ;;
  reset)
    rm -f "$MSG_ID_FILE"
    ;;
  *)
    echo "사용법: notify-step.sh {start|update|done|human-action|reset} ..." >&2
    exit 1
    ;;
esac
```

권한: `chmod +x ~/.config/claude-sync/bin/notify-step.sh`

- [ ] **Step 1.4: 테스트 통과 확인 → 6/6**

- [ ] **Step 1.5: state/wizard-message-id.txt gitignore**

`.gitignore` 끝에:
```
# 부트스트랩 wizard 메시지 ID (머신별, 일회용)
state/wizard-message-id.txt
```

- [ ] **Step 1.6: 자기 PC 실측 (선택)**

```bash
~/.config/claude-sync/bin/notify-step.sh start 13
sleep 1
~/.config/claude-sync/bin/notify-step.sh update 4 13 "🔄" "테스트 단계" "1분 경과"
sleep 1
~/.config/claude-sync/bin/notify-step.sh done 13 "5분"
~/.config/claude-sync/bin/notify-step.sh reset
# 휴대폰 Telegram 에 한 메시지가 변하는 모습 확인
```

- [ ] **Step 1.7: 커밋**

```bash
cd ~/.config/claude-sync
git add bin/notify-step.sh tests/notify-step.bats .gitignore
git commit -m "feat(setup): notify-step.sh — Telegram editMessageText 라이브 progress

- start/update/done/human-action/reset 명령
- state/wizard-message-id.txt 보존 (재개 지원)
- progress bar 13 chars + percentage
- 6 bats tests"
```

---

## Task 2: mac-setup.sh step 함수 통합

**Files:**
- Modify: `bin/mac-setup.sh` (step 함수에 notify-step 1줄 추가)

**기능:**
- 기존 step 함수가 ui_step_header 호출 시 notify-step.sh update 도 같이 호출
- 백그라운드 호출 (mac-setup 실행 부담 X)
- silent fail (notify-step 없거나 토큰 없어도 OK)
- mac-setup 시작 시점에 notify-step start, 완료 시점에 done

다른 에이전트의 mac-setup.sh 자산이라 최소 침범. step 함수 내부 1-2줄 추가만.

- [ ] **Step 2.1: mac-setup.sh의 step 함수 위치 확인**

```bash
grep -n "^step()" ~/.config/claude-sync/bin/mac-setup.sh
# 또는
grep -n "^step " ~/.config/claude-sync/bin/mac-setup.sh
```

다른 에이전트가 작성한 step 함수 형태 (UI lib 호출). 정확한 위치 확인.

- [ ] **Step 2.2: step 함수 보강**

다른 에이전트의 mac-setup.sh의 `step()` 함수 (또는 ui_step_header 호출하는 라인) 안 — `__step_done` 호출 직전 — 에 다음 추가:

```bash
# Phase 3: notify-step 트리거 (silent fail OK)
if [[ -x "$SSOT/bin/notify-step.sh" ]]; then
  bash "$SSOT/bin/notify-step.sh" update "$step_num" "$TOTAL_STEPS" "🔄" "$step_title" 2>/dev/null &
  disown $! 2>/dev/null || true
fi
```

`step_num`, `step_title`, `TOTAL_STEPS` 변수는 mac-setup의 step 함수 안에서 이미 사용 중인 이름과 일치시킬 것 (실제 변수명에 맞춰 조정).

또한 `auto` 모드 시작 시 (main entrypoint에서 `mode=auto` 분기) `notify-step start $TOTAL_STEPS &` 호출 추가, 그리고 모든 step 통과 후 `notify-step done $TOTAL_STEPS "$elapsed" &` 추가.

**중요**: 다른 에이전트 자산이라 변경 최소화. ui-lib 호출에 영향 없게 `&` 백그라운드 + silent fail.

- [ ] **Step 2.3: 자기 PC manual smoke**

`mac-setup verify` 모드로 한 step만 실행 → notify-step 호출되는지 (Telegram 메시지 도착 또는 silent skip) 확인:

```bash
mac-setup --step 1
# Expected: step 1 시작/끝에 notify-step 호출. Telegram 메시지 (있으면).
```

또는 DRY_RUN으로:
```bash
DRY_RUN=1 mac-setup --step 1
# Expected: notify-step DRY_RUN으로 즉시 exit. 영향 없음.
```

- [ ] **Step 2.4: 회귀 — 전체 bats**

```bash
cd ~/.config/claude-sync && bats tests/
# Expected: 모든 tests pass (mac-setup 변경은 bats 영향 X)
```

- [ ] **Step 2.5: 커밋**

```bash
cd ~/.config/claude-sync
git add bin/mac-setup.sh
git commit -m "feat(setup): mac-setup step 함수에 notify-step 통합

- step 함수가 매 단계 진입 시 notify-step update 백그라운드 호출
- auto 모드 시작/끝에 notify-step start/done
- silent fail + & disown (mac-setup 부담 0)"
```

---

## Task 3: bootstrap-new-mac.sh step 함수 통합

**Files:**
- Modify: `bootstrap/bootstrap-new-mac.sh` (step 함수 또는 동등 호출에 1줄 추가)

bootstrap-new-mac.sh는 비대화형 자동 모드. mac-setup 과 비슷한 step 함수 보유.

- [ ] **Step 3.1: bootstrap-new-mac.sh의 step 함수 확인**

```bash
grep -n "^step\(\) {" ~/.config/claude-sync/bootstrap/bootstrap-new-mac.sh
# 또는
grep -n "step \"" ~/.config/claude-sync/bootstrap/bootstrap-new-mac.sh | head -5
```

- [ ] **Step 3.2: step 함수에 notify-step hook 추가**

bootstrap-new-mac.sh의 `step()` 함수 안에 추가:

```bash
# Phase 3: notify-step 트리거
if [[ -x "$SSOT_DIR/bin/notify-step.sh" ]]; then
  step_num=$(echo "$1" | grep -oE '^[0-9]+' | head -1)
  [[ -n "$step_num" ]] && \
    bash "$SSOT_DIR/bin/notify-step.sh" update "$step_num" 15 "🔄" "$1" 2>/dev/null &
  disown $! 2>/dev/null || true
fi
```

(`SSOT_DIR` 는 bootstrap-new-mac.sh 가 정의하는 변수명에 맞출 것; total은 13b 추가 후 약 15.)

스크립트 시작/끝에 `notify-step start 15` / `notify-step done 15` 도 추가:
- 시작: 첫 step 진입 직전
- 끝: `step "✅ 부트스트랩 완료"` 직전 또는 직후

- [ ] **Step 3.3: manual smoke**

bootstrap-new-mac.sh 는 회사 맥북 첫 셋업용 — 자기 PC 에선 실측 어려움. `--dry-run` 같은 옵션이 있는지 확인. 없으면 `head` 로 step 호출만 확인:

```bash
grep -A 2 "^step \"" ~/.config/claude-sync/bootstrap/bootstrap-new-mac.sh | head -20
```

- [ ] **Step 3.4: 커밋**

```bash
cd ~/.config/claude-sync
git add bootstrap/bootstrap-new-mac.sh
git commit -m "feat(setup): bootstrap-new-mac step 함수에 notify-step 통합

- 자동 부트스트랩 진행률 폰에 라이브 중계
- silent fail + & disown
- 회사 맥북 첫 셋업 시 폰 보면 한 메시지가 13단계 progress"
```

---

## Task 4: 사람 액션 별도 알림 통합

**Files:**
- Modify: `bin/mac-setup.sh` (step 3, 11 진입 시 human-action 호출)

**기능:**
- step 3 (1Password 인증) 진입 시 `notify-step human-action "1Password CLI" "..." &`
- step 11 (CLI OAuth 안내) 진입 시 동일

mac-setup 의 step_03_1password / step_11_cli_login 함수 안에 추가.

- [ ] **Step 4.1: 함수 위치 찾기**

```bash
grep -n "^step_03_\|^step_11_" ~/.config/claude-sync/bin/mac-setup.sh
```

- [ ] **Step 4.2: step_03 (1Password) 보강**

`step_03_1password` (또는 동등) 함수 시작 부분 (`ui_step_header 3 ...` 직후) 에 추가:

```bash
if [[ -x "$SSOT/bin/notify-step.sh" ]]; then
  bash "$SSOT/bin/notify-step.sh" human-action "1Password CLI" \
    "데스크톱 앱 → 설정 → 개발자 → '1Password CLI 사용 허용' 토글 ON
터미널에서: op signin
(완료되면 mac-setup 자동 진행)" 2>/dev/null &
  disown $! 2>/dev/null || true
fi
```

- [ ] **Step 4.3: step_11 (OAuth) 보강**

`step_11_cli_logins` (또는 동등) 함수 시작 부분에 추가:

```bash
if [[ -x "$SSOT/bin/notify-step.sh" ]]; then
  bash "$SSOT/bin/notify-step.sh" human-action "CLI OAuth 로그인" \
    "각 CLI에 OAuth 로그인 (한 번씩):
gh auth login / gcloud init / vercel login / supabase login / docker login
firebase login / wrangler login / claude
(상세: bootstrap/cli-login-checklist.md)" 2>/dev/null &
  disown $! 2>/dev/null || true
fi
```

- [ ] **Step 4.4: manual smoke**

`mac-setup --step 3` (또는 그 step 만) 실행 → 별도 Telegram 메시지 도착 (있으면).

- [ ] **Step 4.5: 커밋**

```bash
cd ~/.config/claude-sync
git add bin/mac-setup.sh
git commit -m "feat(setup): step 3/11 human-action Telegram 별도 알림

- 1Password 인증 단계 진입 시 폰에 안내 메시지
- CLI OAuth 단계 진입 시 동일
- 메인 progress 메시지는 그대로 유지 (인라인 표시는 step 함수가 자동)"
```

---

## Task 5: greet.sh — 첫 인사 모먼트

**Files:**
- Create: `bin/greet.sh`
- Create: `tests/greet.bats`

**기능:**
- `greet.sh` (기본): mac-setup 완료 + greeted=false 일 때만 발동, 1회 마킹
- `greet.sh --replay`: 강제 재생 (시연용)
- `greet.sh --skip`: 마킹만 (시퀀스 skip)
- 시퀀스 ~5초:
  - Beat 1: 핸드셰이크 애니메이션 (3초, `\r`)
  - Beat 2: 환영 배너 (페르소나 색)
  - Beat 3: 컨텍스트 핸드오프 (상대 머신 마지막 세션 + 다음 명령 추천)

- [ ] **Step 5.1: 실패 테스트 작성**

Create `tests/greet.bats`:

```bash
load test_helper

setup_persona() {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
}

@test "greet --skip marks greeted without playing sequence" {
  setup_persona
  echo '{"completed":true,"greeted":false}' > "$SSOT/state/wizard-state.json"
  run "$SSOT/bin/greet.sh" --skip
  [ "$status" -eq 0 ]
  greeted=$(jq -r '.greeted' "$SSOT/state/wizard-state.json")
  [ "$greeted" = "true" ]
  # 출력 없어야 (시퀀스 skip)
  [ -z "$output" ]
}

@test "greet (default) silent if not completed" {
  setup_persona
  echo '{"completed":false,"greeted":false}' > "$SSOT/state/wizard-state.json"
  run "$SSOT/bin/greet.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "greet (default) silent if already greeted" {
  setup_persona
  echo '{"completed":true,"greeted":true}' > "$SSOT/state/wizard-state.json"
  run "$SSOT/bin/greet.sh"
  [ -z "$output" ]
}

@test "greet (default) plays sequence and marks greeted when conditions met" {
  setup_persona
  echo '{"completed":true,"greeted":false}' > "$SSOT/state/wizard-state.json"
  # 상대 머신 마지막 세션
  TS_RECENT=$(date -v-30M +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  echo "{\"ts\":\"$TS_RECENT\",\"host\":\"회사맥프로\",\"type\":\"session_end\",\"cwd\":\"/dev/lawblaw\",\"duration_min\":22,\"summary\":\"fix(auth)\"}" \
    > "$SSOT/state/activity/회사맥프로.jsonl"

  # FAST_GREET=1 환경변수로 sleep 단축 (테스트 빠르게)
  FAST_GREET=1 run "$SSOT/bin/greet.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"홈맥에어"* ]]
  [[ "$output" == *"회사맥프로"* ]] || [[ "$output" == *"안녕"* ]]
  greeted=$(jq -r '.greeted' "$SSOT/state/wizard-state.json")
  [ "$greeted" = "true" ]
}

@test "greet --replay plays sequence regardless of greeted state" {
  setup_persona
  echo '{"completed":true,"greeted":true}' > "$SSOT/state/wizard-state.json"
  FAST_GREET=1 run "$SSOT/bin/greet.sh" --replay
  [ "$status" -eq 0 ]
  [[ "$output" == *"홈맥에어"* ]] || [[ "$output" == *"회사맥프로"* ]]
}

@test "greet handles missing wizard-state.json gracefully" {
  setup_persona
  rm -f "$SSOT/state/wizard-state.json"
  run "$SSOT/bin/greet.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
```

- [ ] **Step 5.2: 테스트 실패 확인 → 6 failures**

- [ ] **Step 5.3: bin/greet.sh 구현**

Create `bin/greet.sh`:

```bash
#!/usr/bin/env bash
# greet.sh — 첫 인사 모먼트 (mac-setup 완료 후 첫 셸 1회)
# 사용법:
#   greet.sh           기본 (조건 만족 시 1회만)
#   greet.sh --replay  강제 재생 (시연용)
#   greet.sh --skip    마킹만, 시퀀스 skip
#
# 환경:
#   FAST_GREET=1   sleep 단축 (테스트용)

set -uo pipefail

SSOT="$HOME/.config/claude-sync"
PERSONA_BIN="$SSOT/bin/persona.sh"
LEDGER_DIR="$SSOT/state/activity"
WIZARD_STATE="$SSOT/state/wizard-state.json"

mode="${1:-default}"

# wizard-state 읽기
if [[ -f "$WIZARD_STATE" ]]; then
  completed=$(jq -r '.completed // false' "$WIZARD_STATE" 2>/dev/null)
  greeted=$(jq -r '.greeted // false' "$WIZARD_STATE" 2>/dev/null)
else
  completed="false"
  greeted="false"
fi

# 마킹 함수 (greeted=true 로 갱신, 없으면 추가)
mark_greeted() {
  if [[ -f "$WIZARD_STATE" ]]; then
    tmp=$(mktemp)
    jq '.greeted = true' "$WIZARD_STATE" > "$tmp" && mv "$tmp" "$WIZARD_STATE"
  else
    mkdir -p "$(dirname "$WIZARD_STATE")"
    echo '{"completed":true,"greeted":true}' > "$WIZARD_STATE"
  fi
}

case "$mode" in
  --skip)
    mark_greeted
    exit 0
    ;;
  --replay)
    : # 다음으로 가서 시퀀스 재생
    ;;
  default)
    [[ "$completed" == "true" ]] || exit 0
    [[ "$greeted" == "false" ]] || exit 0
    ;;
  *)
    echo "사용법: greet.sh [--replay|--skip]" >&2
    exit 1
    ;;
esac

# sleep 단축
if [[ "${FAST_GREET:-0}" == "1" ]]; then
  SLEEP_BEAT=0
else
  SLEEP_BEAT=1
fi

# 페르소나 정보
self_json=$("$PERSONA_BIN" --json 2>/dev/null) || exit 0
self=$(echo "$self_json" | jq -r '.persona')
self_emoji=$(echo "$self_json" | jq -r '.emoji')
other=$("$PERSONA_BIN" --other 2>/dev/null) || other=""
if [[ "$self" == "홈맥에어" ]]; then
  other_emoji="💼"
else
  other_emoji="🏠"
fi

# Beat 1 — 핸드셰이크 애니메이션 (3초)
echo ""
echo "                              ━━━ 두 맥북 ━━━"
echo ""
printf "   %s %s                                    %s %s\n" \
  "$other_emoji" "$other" "$self_emoji" "$self"
sleep "$SLEEP_BEAT"
printf "\r   %s %s  ●━━━━━━━ →                       %s %s" \
  "$other_emoji" "$other" "$self_emoji" "$self"
sleep "$SLEEP_BEAT"
printf "\r   %s %s  ●━━━━━━━━━━━━━━ → →           → ●  %s %s" \
  "$other_emoji" "$other" "$self_emoji" "$self"
sleep "$SLEEP_BEAT"
printf "\r   %s %s  ●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━●  %s %s\n" \
  "$other_emoji" "$other" "$self_emoji" "$self"
echo "                          🤝 만남"
echo ""

# Beat 2 — 환영 배너
echo "   ╭───────────────────────────────────────────╮"
echo "   │                                           │"
printf "   │     안녕, %s%-30s│\n" "$self " ""
echo "   │                                           │"
printf "   │     %s가 너를 기다리고 있었어%-7s│\n" "$other" ""
echo "   │                                           │"
echo "   ╰───────────────────────────────────────────╯"
echo ""

# Beat 3 — 컨텍스트 핸드오프
self_skills=165
self_rules=5
self_memory_lines=0
[[ -f "$HOME/.claude/projects/-Users-denny/memory/MEMORY.md" ]] && \
  self_memory_lines=$(wc -l < "$HOME/.claude/projects/-Users-denny/memory/MEMORY.md" | tr -d ' ')

echo "   $other 가 너에게 남긴 것:"
echo ""
echo "     📚  ${self_skills}개 스킬"
echo "     📋  ${self_rules}개 규칙 + ${self_memory_lines}줄 메모리"
echo "     🗒  최근 활동 7일치"
echo ""

# 상대 머신 마지막 세션
other_ledger="$LEDGER_DIR/$other.jsonl"
if [[ -f "$other_ledger" ]]; then
  last_session=$(jq -c -r 'select(.type == "session_end") | .' "$other_ledger" 2>/dev/null | tail -1)
  if [[ -n "$last_session" ]]; then
    last_cwd=$(echo "$last_session" | jq -r '.cwd // ""')
    last_summary=$(echo "$last_session" | jq -r '.summary // ""')
    last_ts=$(echo "$last_session" | jq -r '.ts')
    echo "   ─────────────────────────────────────────"
    echo ""
    echo "   $other 가 마지막으로 한 작업:"
    echo ""
    [[ -n "$last_cwd" ]] && echo "     📂  $last_cwd"
    [[ -n "$last_summary" ]] && echo "     💬  \"$last_summary\""
    echo ""
  fi
fi

echo "   ─────────────────────────────────────────"
echo ""
echo "   이어서 작업하려면:"
echo ""
echo "     \$ cd ~/development/<프로젝트>"
echo "     \$ project-init Employee"
echo "     \$ claude              # 또는 codex"
echo ""
echo "   처음부터 둘러보려면:  \$ activity"
echo ""

# 마킹 (replay 모드는 마킹 안 함)
if [[ "$mode" != "--replay" ]]; then
  mark_greeted
fi
```

권한: `chmod +x ~/.config/claude-sync/bin/greet.sh`

- [ ] **Step 5.4: 테스트 통과 → 6/6**

- [ ] **Step 5.5: 자기 PC 실측 (시연 모드)**

```bash
~/.config/claude-sync/bin/greet.sh --replay
# Expected: 핸드셰이크 + 환영 배너 + 컨텍스트 출력
```

- [ ] **Step 5.6: 커밋**

```bash
cd ~/.config/claude-sync
git add bin/greet.sh tests/greet.bats
git commit -m "feat(setup): greet.sh — 첫 인사 모먼트

- Beat 1 핸드셰이크 애니메이션 (3초)
- Beat 2 환영 배너
- Beat 3 컨텍스트 핸드오프 (마지막 세션 + 다음 명령)
- --replay (시연), --skip (마킹만), default (1회)
- FAST_GREET=1 환경변수 (테스트)
- 6 bats tests"
```

---

## Task 6: zsh precmd __maybe_greet hook

**Files:**
- Modify: `shell/zshrc.shared` (precmd hook 추가)

**기능:**
- mac-setup 완료 + greeted=false 면 첫 prompt 시 greet.sh 자동 발동
- 발동 후 greeted=true 마킹 → 이후 prompt에 안 발동

- [ ] **Step 6.1: zshrc.shared 끝에 hook 추가**

```bash
# ── 첫 인사 모먼트 (mac-setup 완료 후 1회) ──────────
__maybe_greet() {
  [[ -x "$HOME/.config/claude-sync/bin/greet.sh" ]] || return 0
  local state="$HOME/.config/claude-sync/state/wizard-state.json"
  [[ -f "$state" ]] || return 0
  # greet.sh 가 자체 조건 검사 (completed && !greeted)
  "$HOME/.config/claude-sync/bin/greet.sh" 2>/dev/null
}

if [[ -z "${__CLAUDE_SYNC_GREET_HOOKED:-}" ]]; then
  autoload -Uz add-zsh-hook 2>/dev/null
  add-zsh-hook precmd __maybe_greet 2>/dev/null
  export __CLAUDE_SYNC_GREET_HOOKED=1
fi
```

- [ ] **Step 6.2: 자기 PC 실측**

```bash
# wizard-state 마커 reset (시뮬레이션)
jq '.greeted = false' ~/.config/claude-sync/state/wizard-state.json > /tmp/ws.json && \
  mv /tmp/ws.json ~/.config/claude-sync/state/wizard-state.json

# 새 셸 → greet 자동 발동 (1회)
exec zsh
# → 핸드셰이크 + 환영 + 컨텍스트 출력 후 일반 prompt
# 다음 명령은 일반 prompt
echo "ok"
```

- [ ] **Step 6.3: 회귀**

```bash
cd ~/.config/claude-sync && bats tests/
# Expected: 모든 tests pass
```

- [ ] **Step 6.4: 커밋**

```bash
cd ~/.config/claude-sync
git add shell/zshrc.shared
git commit -m "feat(setup): zsh precmd __maybe_greet hook

- mac-setup 완료 + greeted=false 시 첫 prompt 1회 greet 발동
- greet.sh 자체 조건 검사 (silent fail)
- 다중 source 가드"
```

---

## Task 7: doctor Phase 3 검증 + 통합 확인

**Files:**
- Modify: `bin/doctor.sh` (Phase 3 섹션 추가)

- [ ] **Step 7.1: doctor.sh 에 섹션 추가**

`bin/doctor.sh` 의 마지막 결과 echo 직전에 추가:

```bash
echo ""
echo "── Phase 3: 셋업 라이브 중계 + 첫 인사 ──"

# Phase 3 helper 실행 권한
for s in bin/notify-step.sh bin/greet.sh; do
  if [[ -x "$SSOT/$s" ]]; then
    echo "✓ $s"
  else
    echo "❌ $s 실행 권한/존재 X"; ((errors++))
  fi
done

# wizard-state.json greeted 마커
if [[ -f "$SSOT/state/wizard-state.json" ]]; then
  if jq -e '.greeted' "$SSOT/state/wizard-state.json" >/dev/null 2>&1; then
    greeted=$(jq -r '.greeted' "$SSOT/state/wizard-state.json")
    echo "✓ wizard-state.greeted = $greeted"
  else
    echo "⚠ wizard-state.json 에 .greeted 필드 없음 (mac-setup 첫 실행 후 자동 추가됨)"
  fi
fi

# zsh precmd greet hook
if grep -q "__maybe_greet" "$SSOT/shell/zshrc.shared" 2>/dev/null; then
  echo "✓ zsh precmd greet hook 등록"
else
  echo "❌ greet precmd hook 미등록"; ((errors++))
fi

# mac-setup 의 step 함수에 notify-step 통합?
if grep -q "notify-step" "$SSOT/bin/mac-setup.sh" 2>/dev/null; then
  echo "✓ mac-setup.sh notify-step 통합"
else
  echo "⚠ mac-setup.sh notify-step 미통합 — 부트스트랩 라이브 중계 X"
fi

# bootstrap-new-mac 도 동일
if grep -q "notify-step" "$SSOT/bootstrap/bootstrap-new-mac.sh" 2>/dev/null; then
  echo "✓ bootstrap-new-mac.sh notify-step 통합"
else
  echo "⚠ bootstrap-new-mac.sh notify-step 미통합"
fi
```

- [ ] **Step 7.2: doctor 실행**

```bash
~/.config/claude-sync/bin/doctor.sh
# Expected: Phase 3 섹션 모두 ✓ (또는 ⚠ — 자기 PC 환경)
```

- [ ] **Step 7.3: 모든 bats 회귀**

```bash
~/.config/claude-sync/bin/test.sh
# Expected: 60+ tests pass
```

- [ ] **Step 7.4: Phase 3 마무리 커밋**

```bash
cd ~/.config/claude-sync
git add bin/doctor.sh
git commit -m "chore(doctor): Phase 3 검증 추가 — 셋업 라이브 중계 + 첫 인사

Phase 3 완료. 두 맥북 살아있음 시스템 (Phase 1+2+3) 통합."
```

---

## Phase 3 완료 검증 체크리스트

- [ ] `bin/notify-step.sh start/update/done` 정상 호출
- [ ] mac-setup 실행 시 Telegram 1메시지가 라이브 갱신
- [ ] step 3 (1Password), step 11 (OAuth) 진입 시 별도 알림 메시지
- [ ] 재개 시 같은 메시지 이어서 (state/wizard-message-id.txt 보존)
- [ ] mac-setup 완료 후 첫 셸 진입 시 핸드셰이크 시퀀스 1회
- [ ] `greet --replay` 강제 재생
- [ ] doctor Phase 3 섹션 ✓
- [ ] 모든 bats 회귀 pass

## 다음 단계

Phase 3 완료 → 두 맥북 살아있음 시스템 전체 (Phase 1+2+3) 완성:
- C1 셋업 라이브 중계 ✓
- C2 양 맥북 HUD ✓
- C3 세션 끝 알림 + 출퇴근 catchup + 일일 요약 ✓
- C4 통합 대시보드 (`activity`) — Phase 4 예정 (남음)
- C5 첫 인사 모먼트 ✓

Phase 4 plan 작성: `docs/superpowers/plans/2026-04-29-dual-mac-presence-phase-4.md`
