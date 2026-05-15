# AIDP Pipeline Architecture — 통합 설계 문서

> **목적**: AX 컨설팅 풀 자동화 — 고객 직원 인터뷰부터 코드 배포, 사후 자동 수정(voice2patch)까지의 closed-loop 파이프라인. wishket이 이미 보유한 `aidp-os` 백본 + Nous Research의 `Hermes Agent` + 자체 개발한 5종 어댑터 SKILL.md + 8종 워커 프롬프트 + 신규 개발 필요한 voice2patch 4개 컴포넌트를 합친 단일 시스템.
>
> **버전**: v0.1 (초안, 2026-05-01)
> **작성**: AIDP 자동화 파이프라인 설계 세션 산출물
> **상태**: 설계 문서. PoC 미완. 일부 검증 미완 (`mom` 봇 입력 어댑터 일반화 가능 여부).

---

## 1. 시스템 목적

### 1.1 비즈니스 목표

비-IT 기업의 **AX(AI Transformation) 도입을 가속화**한다. 컨설팅 1건당:

- **앞단**: 4일 동안 8명 직원 인터뷰 (총 30~40시간) → 직원의 암묵지를 명시지로 추출
- **중단**: 추출된 명시지를 lifecycle phase로 정착 → 검증 → aidp-os 입력 변환
- **뒷단**: aidp-os + OMC team 자동 사냥(20시간) → 코드 + 테스트 + 배포
- **사후**: 고객 사용 중 발견되는 이슈/요청을 voice2patch로 자동 수정 closed-loop

목표 리드타임: 인터뷰 시작 → 첫 배포 가동 = **2주 이내** (현재 수동 컨설팅 6~12주 단축).

### 1.2 비즈니스 가치

| 항목 | 현재 (수동 컨설팅) | 본 시스템 |
|---|---|---|
| 인터뷰 정리 | 컨설턴트 1주 | 자동 (저녁 batch) |
| AS-IS 작성 | 컨설턴트 1~2주 | 자동 + 검증 5분 |
| TO-BE 설계 | 컨설턴트 + 도메인 전문가 1주 | 컨설턴트 1일 + AI 보조 |
| 코드 구현 | 외주 개발 4~12주 | 자동 사냥 20시간 |
| 사후 수정 | 추가 외주 의뢰 | voice2patch 자동 |
| 컨설턴트 1인 처리 동시 프로젝트 | 1~2건 | 5~8건 |

### 1.3 비즈니스 차별화

일반 Clarity-style 사용자 행동 분석 SaaS와 달리, AIDP는 **AIDP가 직접 만든 앱들의 closed-loop**:
- SDK 배포·repo 접근·프로젝트 매핑·CI/CD·표준 스캐폴딩·시각 베이스라인이 6가지 인프라가 모두 통합 통제 가능
- 즉 "고객 A가 자기네 앱에 SDK 박는다"가 아니라 "AIDP가 만든 앱에 처음부터 박혀있다"

---

## 2. 전체 아키텍처

### 2.1 풀 시스템 다이어그램

```
═══════════════════════════════════════════════════════════════════
                        맥미니 (24/7 가동 서버)
═══════════════════════════════════════════════════════════════════

┌──────────────────────────────────────────────────────────────┐
│ Hermes Agent (Nous Research)                                  │
│   ├── Telegram / Slack / Signal / Discord / WhatsApp / CLI   │
│   ├── Whisper transcription (음성 → 텍스트)                  │
│   ├── Subagent 병렬 실행                                      │
│   ├── Cron scheduler (scheduled automations)                 │
│   ├── FTS5 session search + Honcho user modeling             │
│   └── agentskills.io 호환 — 5종 SKILL.md 그대로 작동          │
└──────────────────────────────────────────────────────────────┘
                              ↕
┌──────────────────────────────────────────────────────────────┐
│ aidp-os (wishket-aidp/aidp-os)                                │
│                                                                │
│   apps/web (Tenant container)                                 │
│   ├── Phase 0~7 파이프라인 (메뉴트리 → 디자인 → 코드 → 테스트)│
│   ├── FORGE 품질 시스템 (Creator-Critic-Advisor 3-pass)       │
│   ├── 코딩 에이전트 풀 (Claude Code + 빌트인 + Codex)         │
│   ├── Job processor (10가지 잡 타입 분기)                     │
│   └── Quality loop (build verifier 6단계)                     │
│                                                                │
│   src/mom (Slack 봇 — Hermes로 부분/전체 대체 가능)            │
│                                                                │
│   apps/hub (멀티 테넌트 중앙 관리)                            │
│   ├── 테넌트 컨테이너 오케스트레이션                          │
│   └── PostgreSQL                                              │
│                                                                │
│   Traefik + Cloudflare Tunnel (외부 노출)                     │
└──────────────────────────────────────────────────────────────┘
                              ↕
┌──────────────────────────────────────────────────────────────┐
│ voice2patch v1 컴포넌트 (신규 개발 필요)                       │
│   1. 캡처 SDK (rrweb + MediaRecorder + 자동 마스킹)           │
│   2. Spec Extractor (Gemini multimodal)                       │
│   3. mom 봇 입력 어댑터 (Slack-only → webhook 추가)           │
│   4. 변경 클래스 분류기 + FORGE 정책 게이트                   │
│       (copy → 자동 / style → light / layout → 1-click /       │
│        logic → 사람 리뷰)                                     │
└──────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════
                              ↕
                     [고객 영역]
                     - 인터뷰 음성 파일
                     - 배포된 앱 사용
                     - voice2patch 캡처 (SDK 통합)
                     - 직원 검증 체크리스트 답변
═══════════════════════════════════════════════════════════════════
```

### 2.2 단계별 데이터 흐름

```
┌────────── Phase 0: Intake & Interview ──────────┐
│ 고객 자료 수신 (PDF/엑셀/음성/영상/이미지)         │
│ /request-start (자료 정리 + 접수확인서)         │
│ 4일 인터뷰 진행 (각 60~120분)                    │
│ Hermes → 음성 transcribe + 화자 분리            │
└────────────────────────────────────────────────┘
                    ↓
┌────────── Phase 1: Tacit → Explicit ────────────┐
│ /interview-to-phase prep × N (인터뷰 전)         │
│ /interview-to-phase extract × N (인터뷰 후)      │
│ /interview-batch daily-cycle (매일 22시 cron)    │
│   → AS-NNN, ORG-NNN, WF-NNN, SYS-NNN, ROLE-NNN  │
│   → 합의/모순/단독/공백 4분류                    │
│ /interview-batch meta-verify (CFO/책임자 검증)   │
│ /interview-to-phase verify (인터뷰이 검증)       │
└────────────────────────────────────────────────┘
                    ↓
┌────────── Phase 2: Lifecycle Construction ──────┐
│ /project-lifecycle (TB / IMP / UX / WBS 작성)   │
│   → 30.to_be, 40.implementation,                │
│     41.ui_design, 80.project_management         │
│ /phase-validator --strict (8 게이트 검증)        │
└────────────────────────────────────────────────┘
                    ↓
┌────────── Phase 3: Auto Code Generation ────────┐
│ /lifecycle-to-brief                              │
│   → .aidp/brief.json (aidp-os Project record)   │
│   → .aidp/CLAUDE.md (도메인 규칙 + 환각 방지)    │
│   → .aidp/omc-team-pool.json (task pool)        │
│ aidp-os 시스템에 import                          │
│ /oh-my-claudecode:team --pool=... --duration=20h│
│   ├── Claude #1 Architect                        │
│   ├── Claude #2 BE / #3 FE / #4 Tester          │
│   └── Codex #1~4 (BE/FE 보조 / Refactor / Docs) │
│ FORGE 품질 루프 (와이어프레임 / 명세 / 납품)    │
│ Quality loop (build verifier 6단계)              │
└────────────────────────────────────────────────┘
                    ↓
┌────────── Phase 4: Deploy ──────────────────────┐
│ aidp-os 컨테이너 빌드 + 배포                     │
│ Traefik + Cloudflare Tunnel (외부 노출)          │
│ 고객사별 격리 컨테이너                            │
│ 사용자 가이드 (60.user_guide) 자동 생성          │
└────────────────────────────────────────────────┘
                    ↓
                  [고객 사용 시작]
                    ↓
┌────────── Phase 5: voice2patch Closed-loop ─────┐
│ 캡처 SDK (앱에 내장)                             │
│   ├── rrweb DOM 리플레이                         │
│   ├── MediaRecorder 화면 + 음성                  │
│   ├── 자동 마스킹 (PII)                          │
│   └── 사용자 동의 + 1-click 캡처                 │
│ Spec Extractor (Gemini multimodal)               │
│   영상+음성 → spec.json                          │
│ mom 봇 webhook 또는 Hermes gateway               │
│   spec.json 입력                                 │
│ 변경 클래스 분류기 (신규)                         │
│   copy / style / layout / logic 분류            │
│ FORGE 정책 게이트                                 │
│   ├── copy → 즉시 자동 머지                      │
│   ├── style → light Critic + 자동 머지           │
│   ├── layout → standard Critic + 1-click 승인    │
│   └── logic → thorough Critic + 사람 리뷰        │
│ PR / 머지 / 배포                                 │
│ before/after 알림 + 1-click 롤백                  │
└────────────────────────────────────────────────┘
                    ↓
              [고객 사용 — 반복]
```

---

## 3. 컴포넌트 카탈로그

### 3.1 Hermes Agent (외부 — Nous Research)

**위치**: 맥미니에 `curl install`로 배포
**라이선스**: MIT
**Repo**: https://github.com/NousResearch/hermes-agent
**대체 가능**: 부분적 — OpenClaw에서 마이그레이션 가능

**책임**:
- 사용자 인터페이스 (메시징 게이트웨이)
- 음성 → 텍스트 변환
- Subagent 병렬 실행 (다중 인터뷰 batch 처리)
- Cron scheduling (daily-cycle)
- Session memory + cross-session 검색
- 5종 SKILL.md 호스팅 (agentskills.io 표준)

**왜 필요한가**:
- 기존 mom Slack 봇은 Slack 단일 채널, Slack-only 결합
- Hermes는 Telegram/Discord/Signal/WhatsApp/CLI 6채널 + 자체 음성 처리
- closed learning loop로 인터뷰 패턴 학습
- $5 VPS에서도 동작, Daytona/Modal serverless 옵션

**대체 검토**:
- `mom` 봇을 Hermes로 완전 대체 → Slack 한 채널이면 작동, 다른 채널 추가 시 Hermes로 자연스럽게 확장
- 또는 mom + Hermes 병행 → mom은 aidp-os 내부, Hermes는 Phase 0/1/5 게이트웨이

### 3.2 aidp-os (wishket-aidp/aidp-os)

**위치**: 맥미니의 docker compose
**라이선스**: MIT (Mario Zechner 명의)
**커밋**: 회사 자산

**현재 보유 (확인됨, 2026-04-30)**:

| 영역 | 모듈 | 비고 |
|---|---|---|
| AI 게이트웨이 | `src/ai/` | 8 프로바이더 통합 |
| 코딩 에이전트 | `src/coding-agent/` | Claude Code + 빌트인 |
| Slack 봇 | `src/mom/` | 코딩 에이전트 위임 |
| Web UI | `apps/web/` | Next.js 15 + Prisma |
| 멀티 테넌트 Hub | `apps/hub/` | PostgreSQL |
| FORGE 품질 시스템 | `apps/web/src/lib/pipelines/spec/forge-engine.ts` | Critic + Advisor |
| Quality loop | `apps/web/src/lib/quality-loop.ts` | 6단계 빌드 검증 |
| Job processor | `apps/web/src/lib/job-processor.ts` | 10 잡 타입 |

**확인 결과 (검증 질문 b)**:

✅ **FORGE는 변경 클래스별 정책 분기를 지원하지 않음**

근거:
- `forge-engine.ts` 309줄 분석: Creator → Critic → Advisor 3-pass에 분기 없음
- Critic 평가 기준 10개 풀 (구현충분성/엣지케이스/UX/보안/성능/접근성 등) — 모두 명세 품질, 변경 위험도 아님
- `change_class`, `patchType` 등 enum 검색 결과 0건
- `delivery/analysis-engine.ts` 5종 분류 (`mock_data, env_config, db_migration, error_handling, requirement_gap`)는 납품 전 이슈 분류이지 변경 위험도 아님
- `ForgeMode = "quick" | "standard" | "thorough"`는 검증 강도(Critic 비용)이지 변경 종류가 아님

**함의**: voice2patch v1의 변경 클래스 분류기 + 정책 게이트는 **신규 개발 필수** (memory voice2patch 비전 노트와 일치).

**미확인 (검증 질문 a)**:
⚠️ **`mom` 봇 입력 핸들러가 Slack 전용 결합인지** 미확인. 코드 직접 추적 필요.
- 만약 일반화 가능 (webhook 추가 가능) → 신규 개발 200~400 LoC
- 만약 Slack 전용 강결합 → 신규 mom-like 어댑터 작성 필요 (1500 LoC)
- 또는 Hermes로 완전 대체 → mom 폐기, Hermes에 input handler 작성

### 3.3 5종 어댑터 SKILL.md (자체 개발)

**위치**: `~/wishket/claude-settings/.claude/skills/`
**라이선스**: 사내
**호환**: agentskills.io 표준 (Hermes에서 그대로 작동)

| 스킬 | 줄 수 | Phase | 책임 |
|---|---|---|---|
| `interview-to-phase` | 829 | 0 | 단일 transcript → AS/ORG/WF/SYS/ROLE |
| `interview-batch` | 523 | 0 | 다중 transcript 통합 + 모순 탐지 |
| `project-lifecycle` | 3254 (본체+refs) | 1 | TB/IMP/UX/WBS 작성 가이드 |
| `phase-validator` | 331 | 1.5 | 8 게이트 무결성 검증 |
| `lifecycle-to-brief` | 679 + 962 | 2 | aidp-os 입력 + OMC team pool 변환 |

**총 분량**: 약 6850줄 (워커 프롬프트 962줄 포함)

**역할**:
- 각 스킬은 단일 책임 (Phase별 분리)
- agentskills.io 표준 frontmatter (name + description)
- 환각 방지 게이트 명시 (총 14개 = 6 + 8)
- 호출 시 Hermes 또는 Claude Code가 LLM에 system prompt로 주입

**제약**:
- LLM 추론 영역 (인터뷰 분석, 토픽 클러스터링, 합의/모순 탐지)에 적합
- 결정론적 작업 (YAML 파싱, ref 그래프 검증)은 비효율 — 향후 CLI 도구로 일부 이전 검토

### 3.4 워커 프롬프트 (자체 개발)

**위치**: `lifecycle-to-brief/references/workers/`
**구성**: 8명 (4 Claude + 4 Codex) + README

| ID | 모델 | 역할 | priority_score 구간 |
|---|---|---|---|
| C1 | opus | Architect (TB/IMP) | ≥0.8 |
| C2 | opus | BE Implementer (복잡) | ≥0.7, >8h |
| C3 | sonnet | FE Implementer | ≥0.6 |
| C4 | sonnet | Tester | ≥0.5 |
| X1 | codex | BE Helper | 0.5~0.8, ≤8h |
| X2 | codex | FE Helper | 0.5~0.8, 단일 컴포넌트 |
| X3 | codex | Refactorer | lint/build/simplify |
| X4 | codex | Doc Writer | UG/UAT/change_log |

**영역 분리** (충돌 방지):
- BE: `apps/web/src/lib/`, `apps/web/src/app/api/` → C2/X1
- FE: `apps/web/src/components/`, `apps/web/src/app/(pages)/` → C3/X2
- Test: `e2e/` → C4
- Phase 본문: `30~40` → C1
- UG/UAT: `60~70` → X4

### 3.5 voice2patch v1 컴포넌트 (신규 개발)

memory `project_aidp_voice2patch_vision.md` 노트의 4개 빠진 컴포넌트.

| # | 컴포넌트 | LoC 추정 | 기술 스택 |
|---|---|---|---|
| 1 | 캡처 SDK | 1500~2500 | rrweb + MediaRecorder + Web API + masking 룰 |
| 2 | Spec Extractor | 500~800 | Gemini multimodal API + 프롬프트 엔지니어링 |
| 3 | mom 봇 입력 어댑터 | 200~1500 | TS — 일반화 가능 여부에 따라 변동 |
| 4 | 변경 클래스 분류기 + 정책 게이트 | 600~1000 | TS — FORGE 진입 직전 모듈 |

**합계**: 2800~5800 LoC, 1~2개월 개발

**핵심 가이드** (memory 노트 명시):
- ❌ "100% 정확도 10번" 프레임 금지. LLM confidence ≠ 정확도
- ❌ logic 변경 자동 배포 절대 금지
- ✅ v1은 copy/style만 자동, 나머지는 사람
- ✅ 모든 자동 변경에 before/after 알림 + 1-click 롤백 필수

**변경 클래스 분류기 설계 (Option 1 — Pre-FORGE)**:

```
spec.json 입력 → classifier
                    ↓
  ┌─────────────────┼─────────────────┐
copy             style             layout              logic
  ↓                ↓                  ↓                  ↓
FORGE 스킵      light Critic     standard Critic    thorough Critic
즉시 머지       (3 criteria)      (6 criteria)       (10 criteria)
                자동 머지         1-click 승인       사람 리뷰 필수
                                                     + before/after
                                                     + 롤백 가능
```

분류 기준:
- **copy**: 텍스트 변경만 (라벨, 메시지). DB/API/로직 무수정.
- **style**: CSS/Tailwind/색상/간격/폰트만. DOM 구조 무변경.
- **layout**: DOM 구조 변경 (컴포넌트 추가/제거/재배치). 상태/이벤트 핸들러 동일.
- **logic**: 비즈니스 로직, API 호출, 상태 관리, 권한. **자동 배포 절대 금지**.

---

## 4. 인프라 설계

### 4.1 맥미니 사양 (권장)

| 항목 | 최소 | 권장 | 이유 |
|---|---|---|---|
| 모델 | M2 | M4 Pro | 헤르메스 + aidp-os + 8 워커 동시 |
| RAM | 16GB | 32GB | aidp-os 컨테이너 + Postgres + Whisper local |
| 저장 | 256GB SSD | 1TB SSD + 외장 4TB | 인터뷰 음성 누적 + 워크스페이스 |
| 네트워크 | 유선 1Gbps | 동일 | Cloudflare Tunnel |
| 전원 | UPS | 동일 | 24/7 가동 |

**예산**: 권장 사양 약 250~350만원

### 4.2 호스팅 레이아웃

```
맥미니 (단일 노드)
├── Hermes Agent (host process 또는 Docker)
├── aidp-os Docker compose
│   ├── traefik
│   ├── cloudflared
│   ├── postgres
│   ├── hub
│   ├── hub-worker
│   └── tenant-* (고객사별 N개)
├── voice2patch services (Docker)
│   ├── capture-backend
│   ├── spec-extractor
│   └── classifier
└── Volumes
    ├── /data/interviews (음성 + transcript)
    ├── /data/projects (.projects/<name>/)
    └── /data/aidp-os (workspaces, db)
```

### 4.3 외부 노출

```
Cloudflare Tunnel
├── admin.ai-delivery.work → Hub (:4175)
├── <tenant>.ai-delivery.work → Tenant container (:4173)
├── hermes.ai-delivery.work → Hermes (선택, internal-only 권장)
└── voice2patch.ai-delivery.work → 캡처 SDK 백엔드
```

Hermes는 Telegram/Signal 봇 토큰으로 인증하므로 외부 도메인 노출 선택사항.

### 4.4 백업 전략

- **인터뷰 음성**: 외장 SSD 또는 사내 NAS에 매일 rsync (PII 포함, 암호화)
- **.projects/**: Git으로 버전 관리 (private repo)
- **aidp-os DB**: PostgreSQL pg_dump 일일
- **고객 워크스페이스**: Git으로 버전 관리 + Cloudflare R2

---

## 5. 환각 방지 종합 메커니즘

5종 스킬 + 워커 프롬프트 + voice2patch 분류기가 함께 작동하는 14중 방어:

### 5.1 인터뷰 → AS-IS 단계 (게이트 1~6)

`interview-to-phase`에서:

1. 모든 fact에 발언 ID trace
2. 직접 인용 우선 (추론은 별도 마킹)
3. verified 절대 금지 (extract 단계)
4. 모순 가시화 (해소 강요 X)
5. 일반 지식 차단 (인터뷰이가 안 말한 도메인 인용 X)
6. 인터뷰이 검증 루프 (체크리스트 회수 후에만 verified)

### 5.2 다중 인터뷰 통합 단계 (게이트 7~10)

`interview-batch`에서 추가:

7. 글로벌 발언 ID (Day-I-U 형식)
8. 합의 강도 보존 (자동 verified 승급 금지, in_review까지만)
9. 모순 보존 강제 (LLM의 "합리적 자동 선택" reject)
10. 부서 메타 보존 (클러스터링 시 인터뷰이 부서/직급)

### 5.3 phase 작성/검증 단계 (게이트 11~14, 8개 룰)

`phase-validator`에서:

11. Frontmatter schema (필수 필드)
12. Cross-ref 양방향 정합 (upstream/downstream 일치)
13. Phase 작성 순서 (AS → TB → IMP → WBS)
14. Fact summary 정합 (카운트 ↔ 본문)

(추가 4개 게이트):
- TB/IMP 보호 섹션 변경 시 99.requests CHG 경유 필수
- WBS status 전이 규칙 (todo → doing → done/blocked)
- REQ Story ≠ WBS Task 분리
- change_log entry 누락 금지

### 5.4 자동 사냥 단계 (워커 system prompt)

워커 프롬프트가 강제:
- AS의 verified 외 fact 인용 금지
- TB의 차단 요인 5개 외 발명 금지
- IMP의 AC 외 새 요구사항 추가 금지
- 영역 침범 금지 (BE/FE/Test/Doc 분리)
- task 완료 시 phase-validator 자체 호출

### 5.5 voice2patch 단계 (변경 클래스 분류기)

- copy/style → 자동 머지 가능
- layout → 1-click 승인 필수 (사람 인지)
- logic → 사람 리뷰 필수
- 모든 변경 → before/after + 1-click 롤백

이 14중 방어가 **20시간 자동 사냥에서 환각이 새 명세를 만들어 자기 인용하는 패턴을 차단**한다.

---

## 6. 검증 결과 (확정)

### 6.1 검증 완료 (A 단계)

✅ **FORGE 변경 클래스 분기 미지원** (확정, 2026-05-01)
- `forge-engine.ts`, `delivery/analysis-engine.ts`, `design/types.ts` 직접 분석
- 결론: voice2patch v1의 변경 클래스 분류기 + 정책 게이트 신규 개발 필수
- 설계: Pre-FORGE 분류기 (Option 1) 권장
- 분량: 600~1000 LoC

### 6.2 검증 미완 (다음 우선순위)

⚠️ **`mom` 봇 입력 어댑터 일반화 가능성** (memory 노트의 검증 질문 a)
- 확인 위치: `~/wishket/aidp-os/src/mom/main.ts`, `tools/`
- 확인 방법: Slack Socket Mode 결합 강도 + event handler 추상화 가능 여부
- 영향:
  - 일반화 가능 → webhook 핸들러 추가 200~400 LoC
  - Slack 강결합 → mom-like 어댑터 신규 작성 또는 Hermes로 완전 대체
- 시간: 30분~1시간

⚠️ **Hermes의 agentskills.io 호환 실증** (헤르메스 노트북 시운전 시)
- 5종 SKILL.md를 Hermes에 직접 로드 → 호출 동작 확인
- frontmatter 필드 호환 (name, description) 표준 일치 검증
- 시간: 30분 (Hermes 설치 + 1건 호출 시도)

### 6.3 PoC 우선순위

| 우선 | PoC | 시간 | 가치 |
|---|---|---|---|
| 1 | mom 봇 어댑터 검증 | 1시간 | 신규 개발 분량 결정 |
| 2 | Hermes 노트북 시운전 | 1시간 | agentskills.io 호환 실증 |
| 3 | 인터뷰 1건 end-to-end | 1~2일 | 5종 어댑터 통합 검증 |
| 4 | 변경 클래스 분류기 PoC | 2~3일 | voice2patch v1 핵심 |
| 5 | 캡처 SDK 최소 동작 | 3~5일 | rrweb 통합 검증 |

---

## 7. 작업 패키지 (Work Packages)

### WP-1: 인프라 셋업 (1~2주)

- WP-1.1: 맥미니 구입 + 초기 설정
- WP-1.2: Hermes Agent 설치 + Telegram/Slack 봇 토큰 등록
- WP-1.3: aidp-os Docker compose 가동 + Cloudflare Tunnel 연결
- WP-1.4: 5종 SKILL.md 심링크 동기화 (claude-sync)
- WP-1.5: 인터뷰 음성 저장소 + 백업 자동화

### WP-2: 검증 + 시운전 (1주)

- WP-2.1: mom 봇 어댑터 검증 (검증 질문 a)
- WP-2.2: Hermes agentskills.io 호환 실증
- WP-2.3: 인터뷰 1건 end-to-end PoC (가짜 transcript)
- WP-2.4: phase-validator + lifecycle-to-brief 실 데이터 시운전

### WP-3: voice2patch v1 개발 (4~8주)

- WP-3.1: 캡처 SDK (rrweb + MediaRecorder + 마스킹)
- WP-3.2: Spec Extractor (Gemini multimodal)
- WP-3.3: mom 봇 입력 어댑터 (Slack-only → webhook 추가)
  - WP-2.1 결과에 따라 신규 작성 vs 일반화
- WP-3.4: 변경 클래스 분류기 + 정책 게이트 (Pre-FORGE)
- WP-3.5: before/after 알림 + 롤백 UI

### WP-4: 첫 컨설팅 적용 (4주)

- WP-4.1: 고객 1건 4일 인터뷰 진행
- WP-4.2: Phase 0~4 자동 사냥 풀 사이클
- WP-4.3: 배포 + 사용자 가이드 작성
- WP-4.4: voice2patch 캡처 SDK 통합 + 1주 모니터링
- WP-4.5: post-mortem + 워커 프롬프트 v2 튜닝

### WP-5: 운영 + 확장 (continuous)

- WP-5.1: 다른 wishket 컨설턴트 온보딩
- WP-5.2: 산업별 도메인 지식 파일 추가 (knowledge-vault 연동)
- WP-5.3: 추가 인터뷰 기법 도입 (workshops, focus group 등)
- WP-5.4: voice2patch 분류기 정확도 개선 (실 데이터 학습)

---

## 8. 미해결 이슈 / Open Questions

### 8.1 기술 결정 필요

1. **Hermes vs mom 봇**: 완전 대체 / 부분 대체 / 병행?
   - 권장: 부분 대체 — Hermes가 Phase 0/5 게이트웨이 (음성 + 메시징), mom은 aidp-os 내부 Slack 채널 유지
2. **결정론 코드 분리**: SKILL.md의 어떤 부분을 CLI 도구로 이전?
   - 권장 후보: phase-validator의 frontmatter schema 검증, cross-ref 그래프 검증, lifecycle-to-brief의 JSON 합성
3. **인터뷰 transcript 보존 정책**: PII 마스킹 + 보존 기간
   - 법적 요구사항 검토 필요 (개인정보보호법)

### 8.2 비즈니스 결정 필요

1. **고객 동의 모델**: voice2patch 캡처 SDK의 동의 UX
   - 매번 명시적 동의 vs 일회성 약관 + opt-out
2. **자동 머지 정책 범위**: copy 자동 머지의 경계 (예: 법적 표현, 약관 텍스트는 사람 검토 필수)
3. **컨설턴트별 도메인 전문성 매칭**: 무역/제조/유통/금융 등

### 8.3 학술/연구 결정

1. **암묵지 vs 명시지 경계**: 어떤 것을 "검증된 fact"로 인정할 것인가
2. **모순의 의미**: 부서 간 모순이 항상 "분화된 암묵지"인가, 아니면 "잘못된 정보"인가
3. **자동 사냥 결과의 평가**: 사용자 만족도 vs 개발자 코드 리뷰

---

## 9. 다음 세션 첫 행동

memory `project_aidp_voice2patch_vision.md` 노트의 검증 질문 (a)를 해소.

```
~/wishket/aidp-os/src/mom/main.ts 분석:
- Slack Socket Mode 어떻게 결합되어 있는지
- event handler 추상화 가능한지
- input adapter pattern 적용 가능한지
```

이 결과에 따라 WP-3.3 신규 개발 분량이 결정됨.

또한 헤르메스 노트북 시운전(WP-2.2)으로 agentskills.io 호환 실증.

이 둘 끝나면 풀 PoC (WP-2.3) 가능.

---

## 부록 A: 용어집

- **AX**: AI Transformation. 비-IT 기업이 AI 도입으로 업무 자동화하는 과정
- **암묵지 / 명시지**: tacit knowledge / explicit knowledge. 직원의 머릿속 지식 vs 문서화된 지식
- **CTA / CDM**: Cognitive Task Analysis / Critical Decision Method. 암묵지 추출 표준 기법
- **FORGE**: Creator-Critic-Advisor 3단계 AI 검증 시스템 (aidp-os)
- **closed-loop**: 사용자 행동 → 자동 분석 → 자동 수정 → 자동 배포의 순환
- **phase**: project-lifecycle의 14개 표준 폴더 (00.organizations~99.requests)
- **agentskills.io**: AI 스킬 표준 명세 (Hermes 호환)

## 부록 B: 핵심 파일 위치

```
설계 문서: ~/wishket/claude-settings/.claude/docs/aidp-pipeline-architecture.md (이 문서)
5종 SKILL.md: ~/wishket/claude-settings/.claude/skills/{interview-to-phase, interview-batch, project-lifecycle, phase-validator, lifecycle-to-brief}/
워커 프롬프트: ~/wishket/claude-settings/.claude/skills/lifecycle-to-brief/references/workers/
aidp-os 백본: ~/wishket/aidp-os/
memory 노트: ~/.claude/projects/-Users-manager/memory/project_aidp_voice2patch_vision.md
원본 project-lifecycle: github.com/wishket-aidp/demo-lgd/.claude/skills/project-lifecycle
원본 hermes-agent: github.com/NousResearch/hermes-agent
```

## 부록 C: 변경 이력

| 날짜 | 버전 | 작성자 | 내용 |
|---|---|---|---|
| 2026-05-01 | v0.1 | AIDP 자동화 설계 세션 | 초안 작성. A-B-C 단계 산출물 통합. |
