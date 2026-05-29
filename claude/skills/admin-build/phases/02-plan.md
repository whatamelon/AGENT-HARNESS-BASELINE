# Phase 02 — Plan

Planner agent (Claude opus 또는 Codex high-effort) 가 다음 산출.

## 입력

- normalized intake (`input.yaml`)
- gap analysis (`gap-analysis.md`)
- 로드된 SSOT section

## 산출물 (`plan.md`)

```markdown
# Admin Build Plan — <goal>

## 1. Foundation gap
- AdminShell — 신규 생성 / 기존 활용
- PageHeader — ...
- StatusBadge — ...
- (전체 inventory matrix)

## 2. Route inventory (list ↔ detail 강제 페어링)

**모든 list page 는 [id] detail page 필수**. plan 에 list 만 있고 detail 없는 도메인 금지.

| route | type | required_permission | section | worker_lane |
|---|---|---|---|---|
| /admin/orders | list-page | orders.read | 09-tables | table |
| /admin/orders/[id] | detail-page | orders.read | 06-shell-pages | **detail (필수)** |
| /admin/refunds | list-page | refunds.read | 09-tables | table |
| /admin/refunds/[id] | detail-page | refunds.read | 06-shell-pages | **detail (필수)** |

### list page 의무 구성 4종 (no exception)
1. **DataTable abstraction** (TanStack Table 기반) — native `<table>` 직접 사용 금지
2. **FilterBar** — 최소 검색 input + 1 chip/select (status/source/date)
3. **PaginationBar** — page/total/next/prev (server-side pagination 25 default)
4. **Sortable columns** — header click cycles asc/desc + URL `sort`/`order` param sync
5. **Primary column → detail link** (`next/link` to `/{domain}/[id]`)

### detail page 의무 구성 (no exception)
1. **PageHeader** — title + status badge + breadcrumb (list 로 navigable) + primary/secondary actions
2. **Section: Summary** — 주요 식별 정보 (KPI-like)
3. **Section: Detail** — 도메인별 컬럼 그루핑
4. **Activity timeline** (audit_logs/crm_sync_log 있을 때 — W7 inspector)
5. **Related records table** (관계 entity 있을 때)
6. **NotFoundState boundary** — `notFound()` from `next/navigation` when record null
7. **ForbiddenState boundary** — RBAC fail 시

## 3. Data layer
- Types from DB schema → src/types/...
- Zod schema → src/features/orders/schemas.ts
- Query keys → src/features/orders/api.ts
- API endpoints / server actions

## 4. RBAC matrix
- owner/admin/ops/viewer/forbidden × route × action
- enforcement layer per action (server_action / RLS / edge function)
- audit_logs insert 의무

## 5. Worker lane plan

lane priority queue (검증된 순서, 2026-05-28 갱신):

1. **queries** — `src/queries/**` (foundation, DataTable 의존)
2. **services** — `src/services/**` + `src/lib/validations/**`
3. **actions** — `src/actions/**`
4. **shell-wow** — `src/components/admin/shell/**` + dashboard
5. **tables** — list page 본문 (필수 4종 wired)
6. **detail** — **detail page 필수**, list 1개당 detail 1개 1:1 페어링. lane 5 와 동시 진행 권장.
7. **forms** — create/edit forms
8. **carmanager** — 도메인 hero dashboard
9. **command-pal** — ⌘K
10. **verifier** — read-only

**detail lane 누락 금지**. lane 6 가 lane 7-8-9 뒤로 밀리면 list 만 있고 detail 없는 placeholder 어드민 = 사용자 페인 (2026-05-28 사고 — bbakcar-admin v0.1.0 W7 누락).

## 6. Verifier checklist
- L1: dark-class / secret-leak / focus-ring
- L2: foundation-components / structured-keys / route-guards / zod-resolver
- L3: state-taxonomy fixture 4종 × viewport 5종
- L4: axe AA + screenshot

## 7. Assumptions
- (intake 누락 default)
```
