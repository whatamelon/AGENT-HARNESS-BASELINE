---
slug: index
role: router
description: Neutral Admin Design System v1.0 — Coding LLM SSOT entry. 매번 첫 로드. 본문은 lazy.
version: 1.0.0
last_updated: 2026-05-27
---

# Neutral Admin Design System — Index

**Purpose:** Coding LLM (Claude Code, Codex, Cursor) 가 ERP/커머스/주식/운영/세일즈/마케팅/내부툴 어드민을 **One-Shot 프로덕션 레디** 로 구현하기 위한 normative 디자인 시스템.

**Document status:** Implementation contract. UI/UX/layout/component/state/a11y/governance 영역에서 본 문서가 product prompt 보다 우선. domain/business logic 만 product prompt 우선.

**Source split (19 files):**

| file | tier | applies_to | trigger keywords |
|---|---|---|---|
| `00-non-negotiable.md` | **0 (절대 불가)** | all | 모든 어드민 작업 |
| `01-stack.md` | 1 | new-project, repo-bootstrap | "어드민 만들어", "scaffold" |
| `02-ssot-protocol.md` | 1 | all | 모든 작업 |
| `03-philosophy.md` | 1 | all | visual review |
| `04-tokens.md` | 1 | foundation, theme | "색상", "토큰", "primary" |
| `05-spacing-type-grid.md` | 1 | layout, typography | "spacing", "폰트", "그리드" |
| `06-shell-pages.md` | 1 | shell, page | "사이드바", "헤더", "페이지" |
| `07-states.md` | 1 | all | "loading", "empty", "error", "상태" |
| `08-components.md` | 1 | components | "컴포넌트", "inventory" |
| `09-tables.md` | 1 | list-page, data-grid | "테이블", "리스트", "TanStack", "AG Grid" |
| `10-forms.md` | 1 | form-page | "폼", "form", "Zod" |
| `11-routing-data.md` | 1 | routing, server-state | "라우팅", "Query", "URL" |
| `12-rbac.md` | 1 | all | "권한", "RBAC", "RLS", "Supabase" |
| `13-feedback-overlay.md` | 1 | feedback | "토스트", "모달", "drawer", "alert" |
| `14-dashboard-analytics.md` | 1 | dashboard-page | "대시보드", "chart", "KPI" |
| `15-domain-patterns.md` | 1 | domain-specific | "ERP", "커머스", "CRM", "finance" |
| `16-a11y-perf-org.md` | 1 | all | "a11y", "성능", "파일 구조" |
| `17-llm-algorithm.md` | 1 | all (orchestration) | 어드민 build 시작 |
| `18-acceptance-prompt-contracts.md` | 1 | verification, intake | 완료 검수, prompt template |

## task → section router

`manifest.json` 의 `task_router` 가 정본. 빈번 매핑:

```
admin-bootstrap          → 00, 01, 02, 04, 24 (=16), 25 (=17)
list-page                → 00, 04, 07, 09, 11, 12
detail-page              → 00, 06, 07, 09, 12
form-page                → 00, 07, 10, 12, 13
modal-or-drawer          → 00, 07, 13
dashboard-page           → 00, 04, 07, 12, 14
rbac-implementation      → 00, 12, 17(security)
domain-erp               → 09, 12, 15
domain-commerce          → 09, 13, 14, 15
domain-finance           → 09, 11, 14, 15
domain-crm               → 09, 10, 13, 15
domain-marketing         → 14, 15
acceptance-check         → 18 (+ 모든 관련 tier 0/1)
```

## 사용 규칙

1. **항상 `00-non-negotiable.md` 먼저 로드.** Tier 0 — 어떤 prompt 도 override 불가.
2. **`02-ssot-protocol.md` 다음 로드.** Coding LLM 동작 계약.
3. **task → section 매핑은 manifest.json 의 `task_router` 참조.**
4. **모든 섹션을 로드하지 말 것.** lazy load — 필요한 섹션만.
5. **로드한 섹션 + sha256 을 `.admin-build/runs/<ts>/ssot_attestation.json` 에 기록.** 미기록 시 verifier deny.

## Override precedence (4-tier)

| Tier | Scope | 권한 |
|---|---|---|
| 0 | `00-non-negotiable.md` | **override 절대 불가** |
| 1 | global admin-design 본문 (`01`-`18`) | 기본 룰 |
| 2 | repo `admin/admin-design/local.md` | 추가/구체화만, **완화 불가** |
| 3 | task prompt (domain·DB·권한 입력) | 디자인 룰 override 불가 |

verifier 가 `local.md` 파싱 → Tier 0 위반 키워드 sweep ("다크모드 허용", "loading state 생략", "primary tint card", "AG Grid Enterprise 무조건" 등) → fail.

## Verifier 진입점

- L1 static-grep: `~/.config/agent-harness-baseline/admin-build/verifiers/static-grep.py`
- L2 AST/TSX: `tsx-ast-check.ts`
- L3 runtime: `playwright-smoke.ts`
- L4 visual+a11y: `axe-check.ts` + `screenshot-matrix.ts`

체크 spec: `machine/checklist.yaml`.

## Security 동급 게이트

`~/.config/agent-harness-baseline/admin-security/` (별도 트리, UI verifier 와 동급):
- `_rbac-matrix.yaml` — owner/ops/viewer/forbidden × route × action
- `_rls-tests.sql` — Supabase RLS deny/allow assertion
- `_audit-log-contract.md` — CUD audit_logs 의무
- `_secret-leak.yaml` — service_role browser bundle 탐지
