# 두 맥북 살아있음 시스템 (Dual-Mac Presence)

**날짜**: 2026-04-29
**상태**: Design (검토 대기)
**한줄 요약**: 양 맥북의 활동을 양쪽이 인지하고, 새 맥북 셋업이 라이브 중계되며, 일상에서 두 맥북이 서로의 존재를 느끼는 와우 체험 레이어.

---

## 목적 (Why)

기존 `claude-sync` 는 두 맥북의 데이터(스킬, 규칙, 메모리)를 동기화한다. 이 spec은 그 위에 **체험 레이어**를 얹는다. 사용자가 "두 맥북이 진짜로 살아있는 한 시스템"으로 느끼게 한다.

5가지 와우 모먼트:
- **C1 셋업 라이브 중계** — 회사맥 부트스트랩이 폰 메시지 1통에서 진행률 progress
- **C2 양 맥북 HUD** — 셸/Claude statusline 옆에 항상 다른 맥북 상태
- **C3 세션 끝 알림 + 출퇴근 catchup** — 한 머신 작업 끝나면 다른 머신에 ✨ + 폰 푸시. 4시간+ 휴면 후 첫 진입 시 어제 컨텍스트 자동 표시
- **C4 통합 대시보드** — `activity` 명령 → 양 머신 활동 통합 타임라인 + TUI
- **C5 첫 인사 모먼트** — 새 맥북 첫 셸 진입 시 핸드셰이크 애니메이션 + 컨텍스트 핸드오프 (1회)

## 비목적 (Out of scope)

- 머신 간 실시간 양방향 메시징 (git push 즉시 모드 + Telegram 우회로 충분)
- 모바일 앱 개발 (기존 Telegram bot 그대로 활용)
- LLM 기반 세션 요약 (단순 필드 합성으로 — cwd + commit + duration)
- 셋 이상의 머신 지원 (양 맥북만 가정)
- Codex 메모리 누적 (Codex 자체 한계, 그대로)

## 페르소나 (Foundation)

| 머신 | 페르소나 | 색상 | 이모지 |
|------|---------|------|--------|
| 개인 맥북 | `홈맥에어` | 핫핑크 #FF1493 | 🏠 |
| 회사 맥북 | `회사맥프로` | 일렉트릭 블루 #0969DA | 💼 |

`~/.config/claude-sync/.machine.json` 에 머신별 저장. hostname 기준 자동 매칭 + 수동 override 가능.

```json
{ "persona": "홈맥에어", "emoji": "🏠", "color": "#FF1493" }
```

모든 채널(Telegram, HUD, 대시보드, 첫 인사)이 같은 페르소나 사용.

---

## Phase 1 — 공통 인프라

### 활동 Ledger ("두 맥북의 일기장")

- 위치: `claude-sync/state/activity/{persona}.jsonl` (git 추적, 양 머신 동기화)
- 형식: JSONL — 한 줄 = 한 이벤트
- 영구 보존 (사용자 결정)

이벤트 타입:
- `bootstrap_step`, `bootstrap_done` (C1 / C5)
- `session_start`, `session_end` (C2 / C3 / C4)
- `commit` (C4)
- `wake`, `idle` (HUD live indicator)

이벤트 예:
```json
{"ts":"2026-04-29T13:25:00+09:00","host":"홈맥에어","type":"session_end",
 "cwd":"~/dev/lawblaw","tool":"claude","duration_min":22,"commits":3,
 "files_changed":12,"summary":"fix(auth): SSO 토큰 검증"}
```

### 즉시 Push 모드

기존 launchd 30분 cycle에 더해 Stop hook이 발동 시 백그라운드 git push:
- `bin/sync.sh --immediate` 추가
- 다른 맥북 HUD 반영 latency: 30초 이내 목표

### 3채널 동시 발사

활동 발생 → 동시:
1. ledger.jsonl append
2. Telegram 푸시 (사용자 폰 즉시)
3. git push --immediate (다른 머신 동기화)

---

## C1 — 셋업 라이브 중계 (Phase 3)

### 와우 핵심
Telegram bot `editMessageText` API로 **메시지 1통**이 13단계 동안 살아있다. 사용자가 폰 보고 있으면 progress bar가 실시간 갱신.

### 메시지 형식 (편집 갱신)

**시작**:
```
💼 회사맥프로 셋업 시작
░░░░░░░░░░░░░ 0/13 · 0%
⏳ 1. 시스템 사전 점검
⏳ 2. Homebrew + Brewfile
... (이하 13)
```

**중간**:
```
💼 회사맥프로 셋업 중...
▓▓▓▓░░░░░░░░░ 4/13 · 31%
✅ 1. 시스템 사전 점검 (1m)
✅ 2. Homebrew + Brewfile (3m 12s)
🔄 5. 공유 자산 통합
...
⏱ 시작 13:25 · 12분 경과
```

**완료**: 헤더가 `🎉 셋업 완료!` 로 변신, 막대 100%, ETA 사라지고 다음 명령 추천.

### 사람 액션 (step 3, 11)

**별도 메시지 + 메인 인라인 표시 둘 다** (사용자 결정):

별도 메시지 예:
```
🔐 너의 손이 필요해

회사맥프로가 1Password 설정 기다리는 중.
1) 데스크톱 앱 → 설정 → 개발자
2) "1Password CLI 사용 허용" 토글 ON
3) 터미널 op signin

(완료되면 자동 진행)
```

메인 메시지 step 3 줄에 인라인:
```
⏸ 3. 1Password CLI (사람 액션 필요)
```

### 재개

`mac-setup --step N` 으로 멈췄다 재개 시 **같은 메시지 이어서 갱신** (메시지 ID는 `state/wizard-message-id.txt` 보존).

### 매 단계 갱신 (사용자 결정)

13개 단계 매번 `editMessageText`. Telegram rate limit 30 msg/sec 여유 있음.

### 인프라
- 새 헬퍼: `bin/notify-step.sh`
- 상태: `state/wizard-message-id.txt` (메시지 ID + 시작 시각)
- mac-setup.sh / bootstrap-new-mac.sh 의 `step` 함수가 자동 호출
- 토큰/chat_id 미설정 시 silent skip

---

## C2 — 양 맥북 HUD (Phase 2)

### 와우 핵심
매 prompt 옆에 다른 맥북이 살아있다는 표식. 5초 ✨반짝으로 새 활동 자연 알림.

### 형식 (단일 라인 ≤50자)
```
🏠 홈맥에어 ●  💼 회사맥프로 ✨방금
```

상태별 시각:
| 상태 | 표시 | 정의 |
|------|------|------|
| 자기 머신 | `🏠 홈맥에어 ●` | 늘 |
| 상대 활동 중 | `💼 회사맥프로 ✨방금` | <2분 |
| 상대 최근 | `💼 회사맥프로 ⚡5분` | <30분 |
| 상대 잠잠 | `💼 회사맥프로 🕐2h` | <24h |
| 상대 어제 이전 | `💼 회사맥프로 💤어제` | <7일 |
| 상대 조용함 | `💼 회사맥프로 🌑` | 그 이상 |

### 통합 위치 (양쪽 — 사용자 결정)
1. **Claude Code statusline** — `omc-hud.mjs` 새 segment
2. **zsh RPROMPT** (오른쪽 끝)

같은 헬퍼 호출 (`bin/hud-machines.sh --format=line`), 5초 캐시 (`state/hud-cache/`).

### ✨ 5초 반짝 (사용자 결정)
새 ledger 이벤트 도착 → RPROMPT 옆에 5초 동안 `✨ 방금 lawblaw 끝!` 추가 → 일반 표시 복귀.

### `hudm` alias (사용자 결정 — 도입)
자세 정보 1화면:
```
🏠 홈맥에어 ● 활동 중
   - 마지막: claude session in ~/dev/claude-sync (방금)
   - 오늘 commits: 7개

💼 회사맥프로 ⚡ 5분 전
   - 마지막: claude session in ~/dev/lawblaw_dev (5분, 22m, 3 commits)
   - "fix(auth): SSO 토큰 검증"
   - 오늘 commits: 3개
```

### 인프라
- 새 헬퍼: `bin/hud-machines.sh` (`--format=line` / `--format=detail`)
- 캐시: `state/hud-cache/{persona}.txt` (5초 TTL)
- omc-hud.mjs 확장 (silent fail)
- shell/zshrc.shared RPROMPT segment 추가

---

## C3 — 세션 끝 알림 + 출퇴근 Catchup (Phase 2)

### 와우 핵심
Section 1의 모든 활동 push와 분리. **세션 단위 의미 있는 단위**만 push. 출퇴근하며 자연스럽게 어제 컨텍스트 인지.

### Stop hook 트리거 (사용자 결정)
- 세션 ≥ 3분 **또는** commits ≥ 1개
- 짧은 탐색 세션은 noise → skip

### 자동 헤드라인 합성

LLM 안 씀. 단순 합성:
- `cwd basename`
- 세션 시간대의 마지막 git commit message (있으면)
- duration / commits / files_changed

→
```
💼 회사맥프로 · 작업 끝
📂 lawblaw_dev
💬 fix(auth): SSO 토큰 검증
⏱ 22분 · 📝 3 commits · 📂 12 files
```

### 다른 머신 HUD 반응
ledger pull → C2 인프라가 자동 5초 ✨반짝 (별도 작업 없음).

### 출퇴근 Catchup (사용자 결정 — 도입)
- 트리거: zsh `precmd` 첫 호출 시, 마지막 prompt 이후 ≥ 4시간 휴면이면
- 표시:
```
🏠 홈맥에어 깨어남 (8시간 만에)

💼 회사맥프로 어제 한 일:
  • lawblaw_dev · 22분 · "fix(auth): SSO 토큰 검증"
  • lawblaw_dev · 12분 · "chore: deps update"
  • 그 외 commit 4개

오늘 활동 없음.
```
- 1회 표시 후 마킹 (다음 휴면+진입까지 다시 안 보임)

### 일일 요약 (사용자 결정 — 다음날 아침 8시)
- launchd plist 매일 오전 8시 트리거 (출근 직전 도착)
- Telegram 통합 요약:
```
📊 어제의 두 맥북 (04-28 월)

🏠 홈맥에어 · 3 sessions · 47분 · 5 commits
💼 회사맥프로 · 2 sessions · 1h12m · 7 commits
총 1h59m · 12 commits

가장 큰 작업: 💼 lawblaw_dev billing 모듈 (1h12m)
```

### 인프라
- 새 헬퍼: `bin/notify-session-end.sh`, `bin/summarize-session.sh`, `bin/hud-catchup.sh`
- 새 launchd: `launchd/com.denny.claude-sync-digest.plist` (매일 08:00)
- Stop hook 확장: settings.shared.json + ~/.claude/settings.json 에 `notify-session-end.sh` 추가
- catchup 마커: `state/last-prompt-ts.txt` (zsh precmd 가 갱신)

---

## C4 — 통합 대시보드 `activity` (Phase 4)

### 와우 핵심
양 머신의 모든 흔적을 한 화면. 페르소나 색이 시간 따라 섞이는 그림.

### 명령
```bash
activity              # 7일 (기본)
activity 30d          # 30일
activity today        # 오늘
activity lawblaw      # 프로젝트 필터 (cwd basename)
activity 회사맥프로    # 머신 필터
activity --tui        # fzf 인터랙티브 (사용자 결정 — 도입)
activity --json       # 다른 도구 파이프
```

### 출력 (텍스트 모드)

```
═══════════════════════════════════════════════════════════
   두 맥북 · 최근 7일 · 총 18h 47m · 47 commits
═══════════════════════════════════════════════════════════

📅 04-29 화 (오늘)  🏠 47m + 💼 1h12m  ▓▓▓▓░░░░░░
   ✨ 13:25  🏠 lawblaw_dev · 22m · "fix(auth): SSO 토큰..."
       11:00  💼 lawblaw_dev · 1h12m · "feat(billing): 결제 모달"
       09:30  🏠 claude-sync · 47m · "feat: cross-tool sync"

📅 04-28 월         🏠 2h00m + 💼 35m  ▓▓▓▓▓▓░░░░
       ...

[ 통계 ] 요일별 활동 시간 (사용자 결정 — 도입)
   월 ▓▓▓▓░  화 ▓▓▓▓▓▓  수 ▓▓░  목 ▓░  금 ▓▓▓  토 ▓  일 ▓▓▓▓
[ 모멘텀 ] 어제 대비 +20%
```

### TUI 모드 (`--tui`)
fzf 활용 (Brewfile 의존 — 미설치 시 fallback 평문):
- ←→ 일자 / ↑↓ 세션 / Enter → 자세 정보
- preview pane: commits 리스트, 변경 파일, 시작/끝 시각

### 인프라
- 새 헬퍼: `bin/activity.sh` (alias `activity`)
- 데이터: `state/activity/{persona}.jsonl` 양 머신 합쳐 시간순 sort
- 출력: ANSI truecolor, unicode 막대그래프
- TUI: fzf preview wrapper

---

## C5 — 첫 인사 모먼트 (Phase 3)

### 와우 핵심
회사맥프로가 처음 깨어날 때, 홈맥에어가 거기 있다. **딱 1회만**.

### 시퀀스 (~5초)

**Beat 1 — 핸드셰이크 (3초 애니메이션, 사용자 결정)**

`\r` carriage return 으로 한 줄 점진 갱신:
```
[1.0초] 🏠 홈맥에어 ●━━━━━━━ →                       ○ 💼 회사맥프로
[2.0초] 🏠 홈맥에어 ●━━━━━━━━━━━━━━ → →           → ● 💼 회사맥프로
                          ── 동기화 중 ──
[3.0초] 🏠 홈맥에어 ●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━● 💼 회사맥프로
                            🤝 만남
```

**Beat 2 — 환영 배너 (정적)**

페르소나 색 그라데이션 (`ui-lib.sh` 활용):
```
   ╭───────────────────────────────────────────╮
   │                                           │
   │     안녕, 회사맥프로                        │
   │                                           │
   │     홈맥에어가 너를 기다리고 있었어          │
   │                                           │
   ╰───────────────────────────────────────────╯
```

**Beat 3 — 컨텍스트 핸드오프**

```
   홈맥에어가 너에게 남긴 것:
     📚 165개 스킬 · 📋 5 규칙 + 47줄 메모리 · 🗒 7일 활동

   홈맥에어 마지막 작업:
     📂 lawblaw_dev · 22분 전
     💬 "fix(auth): SSO 토큰 검증"

   이어서 작업하려면:
     $ cd ~/dev/lawblaw_dev
     $ project-init Employee
     $ claude

   처음부터 둘러보려면:  $ activity
```

### 트리거 조건 (1회)
- mac-setup 완료 → `state/wizard-state.json: { greeted: false }`
- zsh `precmd` 첫 호출 시 체크 → 발동 → `greeted: true` 마킹
- 이후 일반 prompt

### Replay/Skip (사용자 결정 — replay alias 노출)
- `greet --replay` (시연용)
- `greet --skip` (마킹만)

### 추가 와우 후보 (사용자 결정 — 모두 X)
사운드/macOS notification/페르소나별 다른 문구 → **도입 안 함**. 위 시퀀스만.

### 인프라
- 새 헬퍼: `bin/greet.sh`
- zsh hook: `shell/zshrc.shared` 에 `__maybe_greet` precmd 추가
- 애니메이션: `\r` carriage return + sleep 0.5

---

## Phase 별 구현 순서

| Phase | 내용 | 예상 시간 | 의존 |
|-------|------|---------|------|
| **1** | 공통 인프라 (페르소나 + ledger + 즉시 push) | 3h | - |
| **2** | C2 (HUD) + C3 (Stop hook + catchup + 일일요약) | 6h | Phase 1 |
| **3** | C1 (셋업 라이브 중계) + C5 (첫 인사) | 6h | Phase 1, 2 |
| **4** | C4 (대시보드 + TUI) | 4h | Phase 1 |
| **합계** | | **~19h** | |

각 Phase 끝에 검증 + 커밋. Phase 1 끝나면 점진적 가치 도출.

---

## 검증 기준

### Phase 1
- [ ] `.machine.json` 양 머신에서 다른 페르소나
- [ ] `state/activity/{persona}.jsonl` 이벤트 append 작동
- [ ] git push 즉시 모드 30초 이내 다른 머신 도착

### Phase 2
- [ ] HUD 라인이 Claude statusline + zsh RPROMPT 양쪽 표시
- [ ] 새 활동 도착 시 5초 ✨ 반짝
- [ ] `hudm` 자세 정보 출력
- [ ] Stop hook이 ≥3분 또는 ≥1commit 세션만 push
- [ ] 4시간+ 휴면 후 첫 prompt 시 catchup 1회
- [ ] 매일 08:00 일일 요약 Telegram 도착

### Phase 3
- [ ] mac-setup 실행 시 Telegram 1통 메시지가 매 단계 갱신
- [ ] step 3 / 11 진입 시 별도 메시지 + 메인 인라인 표시
- [ ] mac-setup 완료 후 첫 셸 진입 시 핸드셰이크 시퀀스 1회 자동
- [ ] `greet --replay` 동작

### Phase 4
- [ ] `activity` 7일 출력
- [ ] `activity --tui` fzf 인터랙티브
- [ ] 필터 (프로젝트/머신/날짜) 동작
- [ ] 요일별 막대그래프 + momentum 표시

### 통합
- [ ] `cs-doctor` 에 Phase별 검증 항목 추가
- [ ] 양 머신에서 동일 동작 (개인 맥북에서 self-test)

---

## 한계 / 보안

- **회사 맥북 정보 풀 노출** (사용자 결정) — cwd / commit message / 파일 이름 모두 개인 폰에 push. 회사 컴플라이언스는 사용자 책임.
- **두 머신만 가정** — 셋 이상은 페르소나/ledger 분기 추가 필요 (현재 비목적)
- **git을 통신 매체로 사용** — 즉시 push 모드로도 ~30초 latency. 0초 X.
- **Telegram 의존** — 봇 토큰/chat_id 1Password에 보관. 미설정 시 모든 push 기능 silent skip.
- **Codex 한계** — 메모리 누적 / 훅 X. 메모리는 CC → Codex 단방향 (claude-sync 한계 그대로).

---

## 인프라 추가 요약

### 새 파일

**bin/**
- `notify-step.sh` (C1)
- `notify-session-end.sh` (C3)
- `summarize-session.sh` (C3)
- `hud-machines.sh` (C2, hudm)
- `hud-catchup.sh` (C3)
- `activity.sh` (C4, alias `activity`)
- `greet.sh` (C5, alias `greet`)

**state/**
- `activity/{persona}.jsonl` (Phase 1)
- `wizard-message-id.txt` (C1)
- `hud-cache/{persona}.txt` (C2)
- `last-prompt-ts.txt` (C3 catchup)

**기타**
- `.machine.json` (Phase 1)
- `launchd/com.denny.claude-sync-digest.plist` (C3 일일요약)

### 수정 파일

- `bin/sync.sh` — 즉시 push 모드 옵션
- `bin/mac-setup.sh` — `step` 함수에 `notify-step` 호출
- `bin/bootstrap-new-mac.sh` — 동일
- `bin/doctor.sh` — Phase별 검증 항목
- `claude/settings.shared.json` + `~/.claude/settings.json` — Stop hook에 `notify-session-end` 추가
- `claude/hud/omc-hud.mjs` — HUD segment 추가
- `shell/zshrc.shared` — RPROMPT segment + precmd hook + alias (`hudm`, `activity`, `greet`)
- `README.md` — 새 도구 안내 섹션
