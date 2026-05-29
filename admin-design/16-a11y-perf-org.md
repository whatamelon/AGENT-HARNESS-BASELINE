---
slug: a11y-perf-org
tier: 1
applies_to: [all, code-organization]
must:
  - radix_shadcn_for_a11y_primitives
  - keyboard_navigation_works
  - visible_focus_state
  - server_pagination_for_large_data
  - kebab_case_files_pascal_components
  - extract_when_jsx_appears_3_times
must_not:
  - remove_outline_without_replacement
  - fetch_unbounded_lists
  - multiple_date_or_chart_libraries
  - duplicate_primitive_layers
cross_ref: [00-non-negotiable, 08-components, 09-tables, 11-routing-data]
verifier_probes:
  - id: focus-ring-present
    layer: L1
    grep: "focus:outline-none(?!\\s+focus-visible:)"
    expect: 0
  - id: no-unbounded-list
    layer: L2
    rule: "useQuery for list endpoint must include {page, pageSize} or cursor; raw 'SELECT *' without limit forbidden"
  - id: no-duplicate-date-lib
    layer: L1
    grep: "from \\\"moment\\\"|from 'moment'"
    expect: 0
    allow_if: "package.json has only one of [date-fns, dayjs, luxon]"
---

# 22. Accessibility Rules

## 22.1 General

- shadcn/Radix 우선 — dialog/menu/select/tooltip/popover/checkbox/radio/tab/accordion.
- semantic HTML.
- icon-only interactive button 에 accessible label.
- form label 은 programmatically associated.
- dialog 에 title + description.
- 모든 control 키보드 navigation 동작.
- focus state 가시.

## 22.2 React Aria 예외

advanced interaction 시에만:
- accessible drag-and-drop
- complex keyboard multi-selection
- advanced collection/table interaction
- custom date/calendar (primitive 너머)

global 도입 금지.

## 22.3 Focus rules

- focus ring 가시.
- replacement 없이 outline 제거 금지.
- dialog 열림 → 내부 focus.
- dialog 닫힘 → trigger 로 focus 복귀.
- destructive confirm 은 cancel 기본 focus (product 가 destructive focus 명시 요청 시 예외).

---

# 23. Performance Rules

## 23.1 Data fetching

- unbounded list fetch 금지.
- 큰 데이터: server pagination/filter/sort.
- query caching.
- 작은 state 변화에 전체 table re-render 회피.

## 23.2 Table performance

Virtualization 사용 조건:

```txt
visible rows > 200
or row rendering 비싸다
or viewport table height 고정 + 크다
```

Server pagination 사용 조건:

```txt
total rows > 1,000
or filter/sort 가 canonical server data 위에서 동작
```

## 23.3 Bundle discipline

- 작은 feature 위해 큰 lib 도입 금지.
- date lib 다중 금지.
- chart lib 다중 금지.
- primitive layer 중복 금지.
- 어드민 도메인 큰 경우 code split.

---

# 24. File and Code Organization

## 24.1 Recommended structure

```txt
src/
  components/
    ui/                 # shadcn/ui owned components
    admin/              # design-system admin components
  features/
    orders/
      api.ts
      columns.tsx
      components/
      routes/
      schemas.ts
      types.ts
    users/
    settings/
  lib/
    auth/
    rbac/
    query/
    format/
    utils.ts
  routes/               # TanStack Router route files if SPA
  styles/
    globals.css
```

## 24.2 Component naming

specific:

```txt
OrdersTable
OrdersFilterBar
OrderStatusBadge
OrderDetailDrawer
RefundConfirmDialog
```

generic primitive 는 generic 유지:

```txt
DataTable
PageHeader
StatusBadge
ConfirmDialog
PermissionGate
```

## 24.3 Reuse rule

- 동일 JSX 3회 등장 → extract.
- 동일 table behavior 2회 → `DataTable`/hooks 로 중앙화.
- 동일 permission check 2회 → RBAC helper 로 중앙화.
