---
slug: acceptance-prompt-contracts
tier: 1
applies_to: [verification, intake, completion]
must:
  - apply_full_acceptance_checklist_before_done
  - use_intake_template_for_one_shot_runs
must_not:
  - skip_acceptance_items_silently
  - mark_complete_with_failing_typecheck_or_build
cross_ref: [00-non-negotiable, 02-ssot-protocol, 17-llm-algorithm, machine/checklist.yaml]
verifier_probes:
  - id: full-acceptance-pass
    layer: L1+L2+L3+L4
    rule: "all applicable items in §27 pass; verifier produces final-verdict.md"
---

# 27. Acceptance Checklist

다음 모두 통과해야 generated admin = done.

## 27.1 Visual
- [ ] Background white.
- [ ] dark mode toggle/class 없음.
- [ ] UI 가 mostly black/white/gray.
- [ ] Primary 가 허용 영역에만.
- [ ] Border 가 surface 명확 구분.
- [ ] 4px grid spacing.
- [ ] Table dense 하지만 readable.
- [ ] Layout 이 11" iPad ~ 32" monitor 동작.

## 27.2 Components
- [ ] AdminShell.
- [ ] PageHeader.
- [ ] State components.
- [ ] DataTable abstraction.
- [ ] Form pattern.
- [ ] ConfirmDialog.
- [ ] StatusBadge.
- [ ] PermissionGate (or equivalent).

## 27.3 Data
- [ ] Unbounded list query 없음.
- [ ] Query key structured.
- [ ] Mutation 이 cache invalidate/update.
- [ ] Server error 가 user-safe message 로.
- [ ] Form 이 validation 사용.

## 27.4 UX states
- [ ] Loading.
- [ ] Empty.
- [ ] Error.
- [ ] Forbidden.
- [ ] Not found.
- [ ] Pending mutation.
- [ ] Success toast.
- [ ] Destructive confirmation.

## 27.5 Security/RBAC
- [ ] Route 가 permission check.
- [ ] Action 이 permission check.
- [ ] Sensitive operation 이 server-enforced.
- [ ] Service role/secret key 가 browser 미노출.
- [ ] Forbidden UI 가 sensitive data 미노출.

## 27.6 Engineering
- [ ] Typecheck pass.
- [ ] Lint pass (or known issues reported).
- [ ] Build pass.
- [ ] Mock data 없음 (production page).
- [ ] TODO placeholder 없음 (user-facing path).
- [ ] Final report 가 assumption 명시.

---

# 28. Prompt Template for One-Shot Coding LLM Execution

Claude Code, Codex 등 어드민 build 요청 시 본 template.

```md
You are implementing a production-ready admin using the Neutral Admin Design System v1.0 (at `~/.config/agent-harness-baseline/admin-design/`).

Treat the design system as normative. Do not ask design questions. If information is missing, infer safe defaults from the document and log assumptions at the end.

## Goal
[어드민 build 목적]

## Domain
[ERP / commerce / stock / operations / sales / marketing / internal tool / other]

## Admin users
[페르소나 + 각 사용자 행동]

## Roles and permissions
[role + permission hierarchy]

## DB schema / API contract
[table, column, enum, relationship, API endpoint, generated type]

## Required pages
[page/route list]

## Required actions
[create/update/delete/approve/refund/export/import]

## Business rules
[constraint, validation, workflow rule]

## Auth/RBAC details
[현재 auth provider + server-side enforcement 방식]

## Design requirements
Use the Neutral Admin Design System exactly:
- Light mode only.
- Monochrome neutral surfaces.
- shadcn/ui + Tailwind + Radix-first.
- TanStack Table first.
- Tremor for dashboards.
- AG Grid only if explicitly justified.
- Every page must include loading/empty/error/forbidden/not-found/pending/success states.

## Execution requirements
1. Inspect the repo first.
2. Reuse existing project conventions where compatible.
3. Create shared admin components before feature pages.
4. Implement production data flows, not mock UI.
5. Run typecheck/lint/build if available.
6. Fix errors.
7. Final response must list implemented files, assumptions, commands run, and known issues.
```

---

# 29. Minimal Generated Component Contracts

## 29.1 PageHeader

```ts
type PageHeaderProps = {
  title: string
  description?: string
  badge?: React.ReactNode
  actions?: React.ReactNode
  metadata?: React.ReactNode
}
```

Visual:

```txt
flex items-start justify-between gap-4 border-b border-border pb-4
```

## 29.2 StatusBadge

```ts
type StatusBadgeProps = {
  status: string
  tone?: "neutral" | "info" | "success" | "warning" | "danger" | "muted"
  withDot?: boolean
}
```

## 29.3 ConfirmDialog

```ts
type ConfirmDialogProps = {
  title: string
  description: string
  confirmLabel: string
  cancelLabel?: string
  destructive?: boolean
  onConfirm: () => Promise<void> | void
}
```

## 29.4 EmptyState

```ts
type EmptyStateProps = {
  title: string
  description?: string
  action?: React.ReactNode
}
```

## 29.5 DataTable

```ts
type DataTableProps<TData> = {
  columns: ColumnDef<TData, unknown>[]
  data: TData[]
  isLoading?: boolean
  isError?: boolean
  error?: unknown
  empty?: React.ReactNode
  toolbar?: React.ReactNode
  pagination?: React.ReactNode
  onRetry?: () => void
}
```

---

# 30. Final Design Decision Summary

본 시스템 선택:

```txt
Core UI:              shadcn/ui
Theme:                Neutral/Zinc, CSS variables, light-only
Primitive:            Radix first
Styling:              Tailwind CSS
Table default:        TanStack Table
Virtualization:       TanStack Virtual
Heavy grid:           AG Grid only with license/feature justification
Dashboard:            Tremor
Chart low-level:      Recharts
Routing:              TanStack Router
Server state:         TanStack Query
Forms:                React Hook Form + Zod
Security posture:     frontend RBAC + server/database enforcement
```

본 시스템 거부:

```txt
dark mode
brand-heavy UI
colorful surfaces
unbounded tables
mock-only pages
primitive library duplication
AG Grid Enterprise by accident
AG Charts by default
frontend-only security
```

결과: calm, neutral, white-background, data-dense, extensible 어드민. ERP/commerce/finance/ops/sales/marketing/custom internal tool 커버 + coding LLM 이 일관 구현 가능.

---

# 31. Reference Notes for Human Maintainers

기본값 선택 이유:

- shadcn/ui — CSS variable theming 권장 + `background`/`foreground`/`primary` 등 semantic theme token 지원. `components.json` 으로 `baseColor`/`cssVariables` 설정.
- Radix Primitives — unstyled, accessible React primitive. 디자인 시스템 빌딩 블록 적합.
- TanStack Table — headless. product 가 markup/styling 통제 + 강력한 table behavior.
- TanStack Router — type-safe routing + 1급 search param. 어드민 table/filter 와 fit.
- TanStack Query — server state, data fetching, caching, update 관리.
- Tremor — React + Tailwind + Radix + Recharts 기반. dashboard/chart 적합.
- AG Grid Community 무료, Enterprise 기능 다수는 license 필요. 명시 product/license 결정.
- Supabase service/secret key 는 RLS 우회 — browser 노출 절대 금지. admin elevated action 은 backend boundary 경유.

---

# 32. v2 Harness Additions (이 SSOT 와 함께 운영되는 도구)

본 SSOT 는 단독 운영 X. 다음 도구와 통합:

## 32.1 admin-build CLI
`~/.config/agent-harness-baseline/admin-build/bin/admin-build`
외부 orchestrator. intake → research → ralplan → goal/team → 4-layer verifier → run artifact.

## 32.2 4-Layer verifier
- L1 static-grep
- L2 AST/TSX (ts-morph)
- L3 runtime (Playwright)
- L4 visual/a11y (axe + screenshot diff)

## 32.3 Hook gate
- Claude: SessionStart/UserPromptSubmit/UserPromptExpansion/PreToolUse/PostToolUse/Stop
- Codex: SessionStart/UserPromptSubmit/PreToolUse/PostToolUse/Stop + permission_mode

## 32.4 Security 동급 게이트
`~/.config/agent-harness-baseline/admin-security/` — RBAC matrix, RLS test, audit-log contract, secret-leak.

## 32.5 Run audit
`.admin-build/runs/<ts>/` — 완전 재현 가능. attestation, plan, critic, worker logs, verifier report, screenshots.
