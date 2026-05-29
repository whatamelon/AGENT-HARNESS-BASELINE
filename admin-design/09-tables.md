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
  # 강화 (2026-05-29 audit) — §12.12~12.15
  - pagination_preserves_search_params         # page 이동 link 가 q/status/sort 등 보존 (sp.toString() clone)
  - column_sort_opt_in_server_side             # sortKey 있는 헤더만 클릭 정렬 + URL sort/order (server-side)
  - date_cell_exact_timestamp_tooltip          # date 셀은 DateCell (title=정확 timestamp)
  - clear_all_filters_affordance               # active param 있을 때 단일 필터 초기화 노출
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
  # 강화 (2026-05-29 audit)
  - pagination_replaces_whole_query            # <Link href={{query:{page}}}> 로 search string 전체 교체 (필터 소실)
  - all_headers_clickable_without_sortkey      # sortKey 없는 컬럼까지 정렬 버튼 (computed 컬럼 500/dead)
  - bare_formatdate_in_table_cell              # 테이블 date 셀에서 DateCell 없이 formatDate/formatDateTime 직접 (tooltip 누락)
  - fake_hover_underline_on_nonlink            # 비-link 셀에 hover:underline (눌릴 것 같은 fake affordance)
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
  - id: pagination-preserves-params
    layer: L2
    rule: "pagination-links.tsx 의 page link 는 useSearchParams + new URLSearchParams(sp.toString()) clone 후 page 만 set. bare `href={{ query: { page } }}` (search string 전체 교체) 금지"
  - id: column-sort-opt-in
    layer: L2
    rule: "data-table.tsx 가 sortKey meta + useSearchParams 기반 server-side 정렬 헤더 지원 (sortKey 있는 컬럼만 클릭 가능). getSortedRowModel(클라 정렬) 미사용"
  - id: date-cell-tooltip
    layer: L2
    rule: "date-cell.tsx(DateCell, title=정확 timestamp) 존재. 테이블 셀이 formatDate/formatDateTime 직접 호출하면 warn (DateCell 사용 권장)"
  - id: clear-all-filters
    layer: L2
    rule: "DataToolbar 가 active param 있을 때 단일 clear-all(필터 초기화) affordance 노출"
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

## 12.12 페이지네이션은 필터/정렬 state 를 보존한다 (non-negotiable)

list page 의 page 이동 link 가 현재 search param 을 날리면 운영자의 작업 set(검색·필터·정렬)이 매 페이지 이동마다 초기화된다 — 가장 치명적인 list-page 결함. 2026-05-29 audit 에서 `PaginationLinks` 가 `<Link href={{ query: { page } }}>` 만 emit 해 (App Router 에서 query 객체는 search string 전체를 **교체**) q/status/scope/sort/order 를 전량 drop 하는 실제 버그 발견.

```tsx
// 페이지 이동 link — 반드시 현재 param clone 후 page 만 교체 (DataToolbar.commit 과 동일 패턴)
const sp = useSearchParams()
const params = new URLSearchParams(sp.toString())
params.set('page', String(page))
return <Link href={`${pathname}?${params.toString()}`} replace>…</Link>
```

- 금지: 빈 `{ query: { page } }` 객체 href (search string 전체 교체 → 필터 소실). "다른 컴포넌트가 보존한다" 같은 근거 없는 주석 금지.
- toolbar(`DataToolbar.commit`)·filter chip·sort 모두 `new URLSearchParams(sp.toString())` clone 패턴을 쓴다 — pagination 만 예외였던 비대칭이 버그였다.

## 12.13 컬럼 정렬 = opt-in server-side, dead affordance/500 금지 (non-negotiable)

§12 의 `column_sort_via_url_param` MUST 가 "헤더 클릭 → URL sort/order" 인데, audit 결과 server query 는 `.order(params.sort)` 로 정렬을 받지만 UI 헤더가 클릭 불가 + indicator 없음 = **dead MUST** 였다. 동시에 server 가 sort 키를 whitelist 안 하면 (`vehicles.queries.ts`) 임의 컬럼명이 곧장 PostgREST 로 가 unknown 컬럼은 500.

규칙 (둘 다 충족):

1. **opt-in.** 컬럼 meta `sortKey?: string` (= 실제 orderable DB 컬럼명) 가 설정된 헤더만 클릭 가능한 정렬 토글로 렌더. computed/join 컬럼(`sortKey` 없음)은 평범한 `<th>` — dead affordance/500 둘 다 방지.
2. **server-side.** 헤더 클릭은 URL `sort`/`order` 만 다시 쓰고(`page` reset) 서버가 정렬된 row 반환. `getSortedRowModel`(클라이언트 정렬) 쓰지 않는다.
3. **indicator.** 활성 정렬 = ChevronUp(asc)/ChevronDown(desc), 비활성 sortKey 컬럼 = ChevronsUpDown(neutral) + `aria-sort`.

```tsx
// DataTable: sortKey 있는 헤더만 <button> + chevron, click → URL sort/order toggle
const sortKey = (meta as AdminColumnMeta)?.sortKey
{sortKey ? <button onClick={() => onSort(sortKey)}>…<ChevronUp/Down/ChevronsUpDown/></button> : headerContent}
```

## 12.14 Date 셀은 정확 timestamp tooltip (§12.5 강제 형태)

§12.5 "Date: human-readable + tooltip with exact timestamp" 가 자주 누락(formatDate 결과를 bare `<span>` 에 출력, title 없음). 공유 `DateCell` 경유로 강제:

```tsx
// components/admin/data-table/date-cell.tsx
export function DateCell({ value, withTime, className }: {...}) {
  if (!value) return <span className={className}>—</span>
  const d = typeof value === 'string' ? new Date(value) : value
  const exact = Number.isNaN(d.getTime()) ? undefined : d.toLocaleString('ko-KR')
  return <span className={className} title={exact}>{withTime ? formatDateTime(value) : formatDate(value)}</span>
}
```

- table 의 date 컬럼은 `formatDate`/`formatDateTime` 를 셀에서 직접 부르지 말고 `DateCell` 사용. (상대시간 `formatRelative` 은 예외 — 그 자체가 추정 표현.)

## 12.15 Clear-all 필터 + fake affordance 금지

- 검색·필터·정렬 param 이 하나라도 active 면 toolbar 에 단일 "필터 초기화"(전체 reset) affordance 노출. 각 chip 개별 토글만으로 끝내지 않는다. param 0 일 때는 숨김(dead affordance 방지).
- **비-link 셀에 `hover:underline` 금지.** PK 단일 진입(§12.9) 전환 시 이름/제목 셀을 `<div>` 로 바꾸면서 `hover:underline` 를 남기면 "눌릴 것 같은데 안 눌리는" fake affordance. 행에서 underline 되는 건 PkLink 뿐.
