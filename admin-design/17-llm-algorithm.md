---
slug: llm-algorithm
tier: 1
applies_to: [all, orchestration]
must:
  - inspect_before_generate
  - normalize_foundation_first
  - shell_before_features
  - data_layer_before_ui
  - route_layer_before_pages
  - typecheck_lint_build_before_done
  - final_report_lists_assumptions
must_not:
  - skip_inspection
  - generate_mock_data_in_production_paths
  - introduce_arbitrary_one_off_values
  - use_any_without_documenting
cross_ref: [00-non-negotiable, 02-ssot-protocol, 18-acceptance-prompt-contracts]
verifier_probes:
  - id: typecheck-passed
    layer: L1
    rule: "tsc --noEmit exit 0 (or project equivalent)"
  - id: build-passed
    layer: L1
    rule: "pnpm build / npm run build exit 0"
  - id: assumptions-logged
    layer: L2
    rule: ".admin-build/runs/<latest>/assumptions.md exists and is non-empty if intake had missing inputs"
---

# 25. Implementation Algorithm for Coding LLM

One-shot 어드민 build 시 다음 algorithm.

## Step 1 — Inspect

- package.json read
- framework 식별
- routing 식별
- UI library 식별
- auth/session source 식별
- DB/API client 식별
- 기존 component 식별
- lint/typecheck/build command 식별

## Step 2 — Normalize foundation

- 누락 required package 설치 (필요할 때만)
- shadcn/ui init (부재 시)
- Tailwind CSS variable theme 추가/검증
- dark mode behavior 제거
- admin component layer 추가

## Step 3 — Build shell

- AdminShell
- Sidebar
- Topbar
- Breadcrumb
- Page wrapper
- PermissionGate
- State component

## Step 4 — Build data layer

- DB schema → type
- Zod input schema
- API function
- Query key
- Query hook
- Mutation hook
- Error mapping

## Step 5 — Build route layer

- Route 정의
- Search param validation
- Route-level permission check
- NotFound/Forbidden boundary

## Step 6 — Build feature UI

자원별:
1. Index/list page
2. Detail page (유용 시)
3. Create/edit flow (permission 허용 시)
4. Delete/archive/restore (도메인 요구 시)
5. Status + audit display (schema 지원 시)

## Step 7 — Wire interactions

- Filter → URL update
- Pagination → URL update
- Sort → URL update
- Mutation → query invalidate
- Destructive → confirm dialog
- Toast → result 보고
- Form → validate + server error 처리

## Step 8 — Test and harden

- Typecheck
- Lint
- Build
- Error fix
- Tablet/laptop/desktop layout 점검
- loading/empty/error state 검증
- Permission behavior 검증
- dark mode class 없음 검증
- mock data 잔존 없음 검증

## Step 9 — Final report

- 구현 route
- 구현 component
- data/API integration point
- permission model
- assumption
- 실행 command
- 미해결 issue (있을 때만)

---

# 26. Coding Standards

## 26.1 TypeScript

- TypeScript everywhere.
- `any` 회피 (불가피하면 문서화).
- schema/API 에서 domain type 파생.
- form/search param/API payload 는 Zod 로 runtime validation.

## 26.2 React

- 작고 합성 가능한 component.
- server data → TanStack Query.
- local UI state 는 local.
- list state 는 URL.
- prop drilling 회피 (필요할 때만 reasonable hook/context).

## 26.3 Tailwind

- token + semantic class.
- 명확한 사유 없으면 arbitrary one-off value 회피.
- inline style 회피.
- custom CSS 회피 (token, layout primitive, 불가피한 component styling 예외).

## 26.4 Copywriting

direct operational language.

Good:
```txt
Create order
Refund payment
Sync inventory
Export CSV
This customer has no orders yet.
```

Bad:
```txt
Let’s make magic happen!
Supercharge your workflow
Oopsie, something broke
```
