---
slug: tables
tier: 1
applies_to: [list-page, data-grid]
must:
  - tanstack_table_default
  - server_pagination_for_server_data
  - url_search_param_state_sync
  - column_priority_classification
  - status_through_status_badge
  - right_align_numeric_currency
  # 강화 (2026-05-28) — list page 필수 4종 무조건
  - data_table_component_used                 # native <table> 직접 사용 금지, DataTable abstraction 경유
  - filter_bar_for_every_list_page            # 최소 검색 input + 1 chip/select (search/status/source 등)
  - pagination_bar_for_every_list_page        # PaginationBar 컴포넌트 사용, 25 default
  - column_sort_via_url_param                 # sort/order URL param 으로 변경 + header click 가능
  # 강화 (2026-05-29) — PK 단일 진입 + sticky header + 필터 색. §12.9~12.11 참조.
  - pk_first_data_column                       # 1번 데이터 컬럼(선택 checkbox 제외)은 PK(id) 값
  - pk_cell_hash_bold_underline                # PK 셀 = `#`+bold+underline (PkLink 컴포넌트)
  - pk_is_sole_detail_navigation               # 상세 이동은 PK 클릭만. 다른 셀은 네비게이션 금지
  - sticky_list_table_header                   # thead sticky top-0 + opaque bg (스크롤 시 헤더 고정)
  - status_filter_semantic_color               # status 필터 칩은 StatusBadge tone 색 (무채 금지)
must_not:
  - ag_grid_without_license_decision
  - unbounded_list_query
  - row_selection_when_no_bulk_actions
  - truncate_critical_value_without_tooltip
  - native_table_without_abstraction          # <table> raw 직접 사용 — DataTable 우회
  - list_page_without_pagination              # 결과 N개라도 PaginationBar 컴포넌트 render
  - list_page_without_filter_bar              # 빈 결과여도 filter bar shell 노출
  # 강화 (2026-05-29)
  - name_or_title_cell_links_to_detail         # 이름/제목/번호판 등 비-PK 셀에 <Link> 금지 — 진입은 PK 단일
  - non_sticky_list_header                     # thead 가 스크롤에 같이 사라지면 위반
  - monochrome_status_filter                   # status 필터 칩을 흑백 토글로만 두면 위반 (의미색 필수)
cross_ref: [00-non-negotiable, 01-stack, 05-spacing-type-grid, 06-shell-pages, 07-states, 11-routing-data, 12-rbac, 17-status]
verifier_probes:
  - id: tanstack-default
    layer: L2
    rule: "list-page imports '@tanstack/react-table' or DataTable abstraction; ag-grid only with assumptions.md justification"
  - id: url-state-sync
    layer: L3
    rule: "filter/sort/pagination/dateRange interactions must update window.location.search; back/forward restores"
  - id: bulk-action-bar-on-selection
    layer: L2
    rule: "if columns include selection checkbox, BulkActionBar must render when selectedCount>0"
  - id: list-page-has-data-table
    layer: L2
    rule: "list-page (route ending in /page.tsx under list-page mapping) must render DataTable (not native <table>); detect via AST"
  - id: list-page-has-filter-bar
    layer: L2
    rule: "list-page must render FilterBar (or equivalent search input + filter chip group)"
  - id: list-page-has-pagination-bar
    layer: L2
    rule: "list-page must render PaginationBar (or equivalent next/prev with total count)"
  - id: list-page-supports-sort
    layer: L3
    rule: "list-page table column header click cycles asc/desc + URL `sort`/`order` param updates"
  - id: pk-column-sole-detail-entry
    layer: L2
    rule: "list-page (또는 그 _components/*-table.tsx) 의 첫 데이터 컬럼은 pkColumn()/PkLink 로 PK(id) 를 렌더하고 detail [id] 로 링크한다. 이름/제목/번호판 등 비-PK 셀에 <Link href=…Detail( … )> 가 있으면 위반 (진입은 PK 단일)"
  - id: sticky-table-header
    layer: L2
    rule: "DataTable thead className 에 'sticky top-0' + opaque bg (bg-muted/bg-card/bg-background, 반투명 /NN suffix 금지). wrapper 에 overflow-hidden 으로 sticky 무력화 금지"
  - id: status-filter-colored
    layer: L2
    rule: "FilterChip 은 tone(StatusTone) 지원 + paramName==='status' 일 때 toneFor(value) 자동 색칠. 컬러 dot + tint. 흑백 토글만이면 위반"
  - id: detail-page-exists-for-each-list
    layer: L2
    rule: "for every /(protected)/{domain}/page.tsx (list), /(protected)/{domain}/[id]/page.tsx (detail) must exist"
---

# 12. Tables and Data Grids

## 12.1 Default table stack

```txt
TanStack Table + shadcn/ui table primitives + TanStack Virtual when needed
```

용도:
- users, orders, products, campaigns, leads
- inventory, tickets, transactions, log (moderate size)
- CRUD master data, operational queue

## 12.2 Standard table features

domain 적합한 만큼:

```txt
search
sorting
pagination
filtering
column visibility
row selection (bulk action 있을 때만)
row actions
empty/loading/error states
density toggle (data-heavy)
URL search param sync
CSV export (allowed 시)
```

## 12.3 URL state rules

URL search params:

```txt
q
page
pageSize
sort
order
filters
dateFrom
dateTo
view
columns (optional)
density (optional)
```

row selection 은 product 사유 없으면 URL 미저장.

## 12.4 Pagination

Default:

```txt
pageSize = 25
options = [10, 25, 50, 100]
```

- server data: server pagination default.
- unbounded fetch 금지.
- row count unknown → "Load more" or cursor pagination.
- 1,000+ row 또는 dense row → virtualization.

## 12.5 Column rules

```ts
type AdminColumnMeta = {
  label: string
  description?: string
  priority: "required" | "high" | "medium" | "low" | "debug"
  align?: "left" | "center" | "right"
  isNumeric?: boolean
  isCurrency?: boolean
  isDate?: boolean
  canHide?: boolean
}
```

Formatting:
- Number: right align.
- Currency: right align + symbol/code.
- Date: human-readable + tooltip with exact timestamp.
- ID: monospace 는 operationally 유용할 때만.
- Status: `StatusBadge`.
- Action: right aligned, compact dropdown for secondary.

## 12.6 Bulk actions

row selection 은 bulk action 있을 때만 노출.

Bulk action bar:
- selected count
- available actions
- clear selection
- destructive bulk action 에 confirm

## 12.7 AG Grid decision rule

AG Grid 는 default 아님. enterprise option.

다음 중 하나 필수일 때만:

| Requirement | AG Grid justification |
|---|---|
| Large server-side row model | AG Grid Enterprise |
| Row grouping as core workflow | AG Grid Enterprise |
| Pivot tables / aggregations | AG Grid Enterprise |
| Master/detail nested grids | AG Grid Enterprise |
| Excel-like range selection/fill/clipboard | AG Grid Enterprise |
| Enterprise xlsx export with styling/multiple sheets | AG Grid Enterprise |
| Complex finance/operations grid with many power-user features | AG Grid Enterprise |

이외 TanStack Table 사용.

## 12.8 AG Grid license warning

AG Grid Enterprise 기능 사용 시 implementation report 에:

```txt
AG Grid Enterprise features were used. Confirm license before production deployment.
```

Enterprise-only module 우발 사용 금지.

## 12.9 PK 컬럼 = 상세 진입 단일 출구 (non-negotiable for list pages)

운영자가 행을 식별하고 상세로 들어가는 경로는 **PK 한 곳**으로 고정한다. 이름·제목·번호판 같은 의미 라벨을 통째로 링크로 만들면 (a) 어디를 눌러야 상세인지 모호하고, (b) 텍스트 선택/복사와 충돌하고, (c) 행마다 클릭 타깃이 제각각이 된다.

규칙:

1. **1번 데이터 컬럼 = PK(`id`).** row selection checkbox 는 컨트롤이므로 그 다음(=첫 *데이터* 컬럼)이 PK다.
2. **표기 = `#` prefix + bold + underline.** uuid 는 시각적으로만 clamp(`max-w`)하고 `title` 에 전체 값 보존. `font-mono text-xs`.
3. **PK 링크가 상세 진입의 유일한 출구.** 다른 셀(이름/제목/번호판/연락처)은 `<Link>` 로 감싸지 않는다 — 평문.
4. 구현은 공유 factory 경유. native `<Link href={xDetail(id)}>` 를 셀마다 흩뿌리지 않는다.

```tsx
// components/admin/data-table/pk-cell.tsx — 단일 출구
export function PkLink({ id, href }: { id: string; href: string }) {
  return (
    <Link href={href as never} title={id}
      className="inline-block max-w-[140px] truncate align-bottom font-mono text-xs font-bold text-foreground underline underline-offset-2 hover:text-foreground/60">
      #{id}
    </Link>
  )
}
export function pkColumn<T extends { id: string }>(detailHref: (id: string) => string, header = 'ID'): ColumnDef<T> {
  return { id: 'pk', header, meta: { priority: 'required' },
    cell: ({ row }) => <PkLink id={row.original.id} href={detailHref(row.original.id)} /> }
}

// 각 *-table.tsx — 첫 데이터 컬럼으로 prepend, 이름 셀은 평문 <div>
const COLUMNS: ColumnDef<Row>[] = [ pkColumn<Row>(vehicleDetail), /* 이름/가격/상태… (링크 없음) */ ]
```

(이전 §12 규칙 `primary_identifier_links_to_detail` = 이름 컬럼 링크 — 2026-05-29 **폐기**. PK 단일 진입으로 대체.)

## 12.10 Sticky 테이블 헤더 (non-negotiable for list pages)

긴 리스트를 스크롤하면 컬럼 의미를 잃는다. list 테이블 `thead` 는 스크롤 컨테이너 상단에 고정한다.

```tsx
// DataTable wrapper — overflow-hidden 금지 (sticky 무력화). 스크롤 컨테이너는 AdminShell <main overflow-y-auto>.
<div className="rounded-lg border border-border bg-card">
  <table className="w-full text-sm">
    <thead className="sticky top-0 z-10 border-b border-border bg-muted ...">
```

- `sticky top-0 z-10` + **opaque** bg (`bg-muted`/`bg-card`/`bg-background`). 반투명(`bg-muted/40`) 은 row 가 비쳐 금지.
- DataTable 래퍼에 `overflow-hidden`/`overflow-x-auto` 를 걸면 그게 스크롤 컨테이너가 되어 page sticky 가 죽는다 — 걸지 않는다. 가로 스크롤이 꼭 필요하면 그 컨테이너에 `max-h` 를 주고 그 안에서 sticky.
- 상단 모서리 둥글림은 헤더 셀(`[&_tr:first-child_th:first-child]:rounded-tl-lg …`)로.

## 12.11 상태/enum 필터 칩 = 의미색 (non-negotiable)

status 필터 칩을 흑백 토글로만 두면 운영자가 색으로 상태를 못 읽는다. Tier 0 §3(monochrome-first)의 예외 = **status 의미색**(StatusBadge tone)이며 필터 칩에도 동일 적용한다.

- `FilterChip` 은 `tone?: StatusTone` 지원. 미지정 + `paramName === 'status'` 면 `toneFor(value)` 로 **자동** 색 도출 → 모든 status 필터가 페이지 수정 없이 색을 띤다.
- idle = 옅은 tint + 컬러 dot, active = 진한 tint. tone 매핑은 `StatusBadge` 와 동일 의미체계(SSOT §17).
- 비-status enum(소스/유형 등)은 기존 무채 칩 유지 — 색은 상태 의미에만.

```tsx
const resolvedTone = tone ?? (paramName === 'status' ? toneFor(value) : undefined)
// resolvedTone 있으면 CHIP_TONE[tone] (border/bg/dot) 적용, 없으면 흑백 토글
```
