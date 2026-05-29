# admin-build — One-Shot 어드민 헌법-급 하네스 v1.0.0

> "문서를 보게 하는 하네스" 가 아니라 **"문서를 어기면 attestation·verifier·hook 이 막는 헌법"**.

Claude Code + Codex CLI 양쪽에서 **`/admin-build`** 슬래시 명령으로 ERP/커머스/금융/CRM/마케팅 어드민을 1-12h 동안 자동 구축. SSOT (Neutral Admin Design System v1.0) 의 19 섹션 + 머신리더블 spec 7종 + RBAC/RLS/audit 동급 게이트 + 4-layer verifier.

## 디렉토리 구조

```
~/.config/agent-harness-baseline/
├── admin-design/                     # SSOT (단일 정본)
│   ├── index.md                      # router (항상 로드)
│   ├── manifest.json                 # sha256 + task_router + override 정책
│   ├── 00-non-negotiable.md          # Tier 0 (절대 override 불가)
│   ├── 01-stack.md ~ 18-acceptance-prompt-contracts.md
│   ├── _exceptions.md                # 예외 등록 절차 (Tier 0 등록 불가)
│   ├── _local-template.md            # repo local.md 템플릿
│   ├── PHASE0_FINDINGS.md            # 공식 doc 검증 기록
│   └── machine/                      # 머신리더블 spec
│       ├── checklist.yaml            # 4-layer verifier probes
│       ├── tokens.schema.json
│       ├── component-contracts.yaml
│       ├── state-taxonomy.yaml
│       ├── route-patterns.yaml
│       ├── viewport-matrix.yaml
│       └── rbac-matrix.yaml
│
├── admin-security/                   # 보안 SSOT (UI verifier 와 동급)
│   ├── _rbac-matrix.yaml
│   ├── _rls-tests.sql
│   ├── _audit-log-contract.md
│   └── _secret-leak.yaml
│
├── admin-build/                      # 외부 orchestrator
│   ├── bin/admin-build               # Python CLI (attest/verify/run/replay/status)
│   ├── verifiers/
│   │   ├── static-grep.py            # L1
│   │   ├── tsx-ast-check.mjs         # L2 (ts-morph)
│   │   ├── playwright-smoke.mjs      # L3 (state × viewport)
│   │   ├── rbac-runtime-check.mjs    # L3 security
│   │   ├── axe-check.mjs             # L4 a11y
│   │   ├── screenshot-matrix.mjs     # L4 visual
│   │   └── package.json              # peer deps (target repo install)
│   └── README.md                     # 본 파일
│
├── claude/
│   ├── rules/admin-design-context.md         # global rule (auto-load)
│   └── hooks/
│       ├── admin_design_gate.py              # 6-event dispatcher
│       └── admin-design-settings.example.json
└── codex/
    ├── hooks/admin_design_gate.py            # 10-event dispatcher (Codex 사양)
    └── hooks.admin-design.example.json
```

심볼릭 (단일 SSOT, 양쪽 CLI 공유):

```
~/.claude/admin-design     → ~/.config/agent-harness-baseline/admin-design
~/.claude/admin-security   → ~/.config/agent-harness-baseline/admin-security
~/.codex/admin-design      → 동
~/.codex/admin-security    → 동
~/.cursor/admin-design     → 동 (optional)
~/.codex/AGENTS.override.md                  # thin router (precedence top)
~/.claude/skills/admin-build/                # /admin-build skill (Claude)
~/.codex/skills/admin-build/                 # /admin-build skill (Codex)
```

## 운영 흐름

```
사용자: /admin-build (intake.yaml 첨부)
   ↓
0. SessionStart hook → manifest 요약 inject
1. UserPromptSubmit → admin keyword → task→section 매핑 inject (lazy)
2. UserPromptExpansion → /admin-build 명령 → attestation 가이드 inject
3. attest CLI → ssot_attestation.json 생성 (없으면 PreToolUse 가 deny)
4. ralplan iter (plan ↔ critic, APPROVE 까지)
5. team 디스패치 (lane-isolated worktree, Claude+Codex 혼합)
6. PostToolUse → 변경 파일 L1 quick-grep
7. admin-build verify → 4 layer
8. fail 시 Stop hook 이 continue + orchestrator 가 repair prompt
9. PASS 시 final-verdict.md + run artifact
```

## 4-Layer Verifier

| Layer | Tool | 의존성 | 잡는 것 |
|---|---|---|---|
| L1 static-grep | Python (pyyaml optional fallback) | 없음 | dark class, secret leak, focus-ring, heavy shadow, stack trace |
| L2 AST/TSX | Node + ts-morph + js-yaml (target repo) | dev deps | 컴포넌트 contract, structured keys, zodResolver, route guard, primary cap, tinted card |
| L3 runtime | Node + Playwright + RBAC fixtures | dev deps + chromium | state 5종 × viewport 5종 × fixture 4종 |
| L4 visual+a11y | @axe-core/playwright + screenshot | dev deps | axe AA, screenshot diff baseline |

## 설치 (Claude Code)

```bash
# 1. hook 활성화 — settings.local.json 에 admin-design-settings.example.json 내용 merge
cat ~/.config/agent-harness-baseline/claude/hooks/admin-design-settings.example.json
# 본 JSON 의 "hooks" 키 내용을 ~/.claude/settings.local.json 에 추가

# 2. global rule 자동 로드 확인
ls ~/.config/agent-harness-baseline/claude/rules/admin-design-context.md

# 3. skill 등록 확인
ls ~/.claude/skills/admin-build/
```

## 설치 (Codex CLI)

```bash
# 1. hooks 등록 — ~/.codex/hooks.json 에 hooks.admin-design.example.json merge
cat ~/.codex/hooks.admin-design.example.json
# 본 JSON 의 "hooks" 키 내용을 ~/.codex/hooks.json 에 누적 추가

# 2. AGENTS.override.md 확인 (precedence top, < 4KiB)
wc -c ~/.codex/AGENTS.override.md     # 2.2KiB

# 3. skill 등록 확인
ls ~/.codex/skills/admin-build/
```

## CLI 사용

```bash
# attestation (어드민 코드 작성 전 의무)
admin-build attest --task list-page --worker shell --agent claude

# 빠른 검증 (dev iteration, L1+L2 만)
admin-build verify --fast

# 풀 검증 (L1+L2+L3+L4, Playwright 포함)
admin-build verify

# orchestrator 진입 (intake → ralplan → team → verify loop)
admin-build run --intake .admin-build/intake.yaml --max-iterations 12 --max-wall-clock-h 12

# 재현
admin-build replay 20260527T231320

# 상태
admin-build status
```

## task_router 키

`admin-build attest --task <key>`:

| key | sections (always-load 3 외) |
|---|---|
| `admin-bootstrap` | 01, 04, 06, 16, 17 |
| `list-page` | 04, 07, 09, 11, 12 |
| `detail-page` | 06, 07, 09, 12 |
| `form-page` | 07, 10, 12, 13 |
| `modal-or-drawer` | 07, 13 |
| `dashboard-page` | 04, 07, 12, 14 |
| `rbac-implementation` | 12, 17 |
| `domain-erp/commerce/finance/crm/marketing` | 09/10/13/14, 15 |
| `acceptance-check` | 18, 12, 16 |

## Override precedence (4 tier)

| Tier | Scope | 권한 |
|---|---|---|
| 0 | `00-non-negotiable.md` | **forbidden** |
| 1 | `01-18` global | additive via Tier 2 only |
| 2 | repo `admin/admin-design/local.md` | additive — 완화 불가 |
| 3 | task prompt | domain/business/db/permission only |

## Tier 0 위반 자동 거부

다음 prompt 는 즉시 reject (사용자에게 사유 안내):

- "이번 PR 만 dark mode 켜"
- "mock data 잠시만"
- "loading state 스킵"
- "service_role 클라이언트 노출"
- "RLS 끄고 디버그"
- "AG Grid Enterprise license 없이"
- "audit log 가짜로"

예외 등록 절차는 `~/.claude/admin-design/_exceptions.md` (Tier 0 은 등록 불가).

## Repo local override

repo 별 도메인/브랜드/DB 특수성:

```bash
cp ~/.claude/admin-design/_local-template.md <repo>/admin/admin-design/local.md
# 채우기 → PR review 후 main
```

verifier 가 자동 로드 + Tier 0 완화 키워드 sweep.

## Phase 7 dry-run 결과 (bbakcar-web)

본 README 작성 시점 (2026-05-27) bbakcar-web 검증:

- `admin-build attest --task list-page --agent claude` → ssot_attestation.json 생성 ✓
- `admin-build verify --fast` → L1+L2 PASS (0 hits) ✓
- PreToolUse hook: admin path edit without attestation → **deny** ✓
- PreToolUse hook: 이후 attestation 생성 → **allow** ✓
- PostToolUse hook: `className="dark"` + `SUPABASE_SERVICE_ROLE_KEY` 코드 → **2 warning** (Tier 0 / secret leak) ✓

## 한계 (alpha)

1. **L3/L4 verifier**: peer dep (playwright, ts-morph, js-yaml, @axe-core/playwright) target repo 에 별도 설치 필요. 미설치 시 skip (false PASS 위험).
2. **routes.json**: L3/L4 가 `.admin-build/routes.json` 를 expect. orchestrator (phase 02 plan) 가 emit 필수. 미존재 시 skip.
3. **RBAC fixture token**: `ADMIN_TEST_TOKEN_{owner,ops,viewer,forbidden}` env 필수. 미주입 시 skip.
4. **Stop hook 8회 cap**: 공식 문서 미확인. external orchestrator (`admin-build run` loop) 가 최종 책임.
5. **Codex PreToolUse**: 모든 tool path 완전 intercept 불가 (공식 노트). PostToolUse + verify CLI 가 보완.

## 갱신 절차

SSOT 본문 수정 시:

```bash
# 1. admin-design/<section>.md 수정
# 2. sha256 재계산
cd ~/.config/agent-harness-baseline/admin-design
shasum -a 256 *.md > /tmp/hashes.txt
# 3. manifest.json 의 sha256 / bytes 갱신
# 4. 변경 ChangeLog 적재 (선택)
# 5. 모든 repo 의 .admin-build/runs/<latest>/ssot_attestation.json 은
#    다음 attest 시점에 자동 재계산 — 강제 만료 X
```

## Cross-referenced 글로벌 룰

- `~/.config/agent-harness-baseline/claude/rules/no-design-slop.md` — AI 디자인 슬롭 10 분야
- `~/.config/agent-harness-baseline/claude/rules/no-decorative-eyebrow.md` — 영문 ALL CAPS eyebrow 금지
- `~/.config/agent-harness-baseline/claude/rules/light-mode-enforcement-three-layers.md` — JS+NativeWind+CSS 3 layer
- `~/.config/agent-harness-baseline/claude/rules/hermes-pr-protocol.md` — whatamelon PR 작성 (Hermes)
- `~/.config/agent-harness-baseline/claude/rules/ci-parallelization.md` — CI verify lane 병렬화

## License

Internal. v1.0.0 — 2026-05-27.
