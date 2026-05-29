---
slug: shell-pages
tier: 1
applies_to: [shell, page]
must:
  - admin_shell_skeleton_consistent
  - sidebar_240px_default_collapsed_64px
  - breadcrumb_when_depth_ge_2
  - page_header_specific_title_not_generic
  - drawer_for_short_create_edit
  - full_page_for_complex_multi_section_form
  # 강화 (2026-05-28) — detail page 의무
  - detail_page_for_every_list_resource       # /(protected)/{domain}/[id]/page.tsx 필수
  - detail_page_renders_required_sections     # header + summary + detail sections + activity timeline (있을 때)
  - detail_page_handles_not_found_and_forbidden  # 404/403 boundary 명시
  - detail_page_breadcrumb_back_to_list        # breadcrumb 가 list page 로 navigable
must_not:
  - colored_sidebar_background
  - primary_sidebar_icons_by_default
  - breadcrumb_as_decoration
  - complex_multistep_form_in_modal
  - list_page_without_paired_detail            # list 만 있고 [id] 없는 도메인 금지
cross_ref: [00-non-negotiable, 03-philosophy, 07-states, 09-tables, 10-forms, 12-rbac]
verifier_probes:
  - id: admin-shell-exists
    layer: L2
    rule: "components/admin/{AdminShell,SidebarNav,Topbar,Breadcrumbs,Page,PageHeader} all present"
  - id: breadcrumb-rule
    layer: L2
    rule: "any route with depth>=2 must have breadcrumb (or breadcrumb in PageHeader props)"
  - id: detail-page-paired-with-list
    layer: L2
    rule: "every list page route must have a paired [id] detail page (file system check)"
  - id: detail-page-required-sections
    layer: L2
    rule: "detail page renders PageHeader + Section(summary) + Section(detail) ; activity_timeline if audit_logs available"
  - id: detail-page-not-found-boundary
    layer: L2
    rule: "detail page uses notFound() from next/navigation when record null"
---

# 8. App Shell

## 8.1 Shell structure

모든 어드민 동일 shell.

```txt
AdminShell
├── Sidebar
│   ├── Workspace / product switcher
│   ├── Primary navigation
│   ├── Secondary navigation
│   └── User/account area
├── Topbar
│   ├── Breadcrumb
│   ├── Global search / command menu
│   ├── Environment indicator
│   └── User/actions
└── Main
    ├── PageHeader
    ├── PageToolbar / FilterBar
    ├── Content
    └── Optional DetailDrawer / RightInspector
```

## 8.2 Sidebar rules

- Width: 240px default, 256px large desktop, 64px collapsed.
- Background: white.
- Border: right `border-border`.
- Active item: neutral background + left indicator or font weight. primary 는 thin indicator 로만.
- Icons: gray, primary 기본 금지.
- Section labels: 12px uppercase or small muted text.

## 8.3 Topbar rules

- Height: 56px default.
- Background: white.
- Border-bottom: yes.
- Breadcrumb 포함 (top-level dashboard 제외).
- 6+ major route 면 global command/search 제공.

## 8.4 Breadcrumb

depth 2+ 일 때 사용.

```txt
Home / Orders / #ORD-1234
```

Rules:
- decoration X.
- 마지막 item = 현재 페이지, not clickable.
- 긴 object name truncate.

---

# 9. Page Patterns

## 9.1 Standard page anatomy

```txt
Page
├── PageHeader
│   ├── eyebrow/status optional
│   ├── title
│   ├── description
│   └── actions
├── PageToolbar optional
├── PrimaryContent
└── SecondaryContent optional
```

## 9.2 PageHeader

Required props:

```ts
type PageHeaderProps = {
  title: string
  description?: string
  badge?: ReactNode
  breadcrumbs?: BreadcrumbItem[]
  primaryAction?: Action
  secondaryActions?: Action[]
  metadata?: ReactNode
}
```

Rules:
- title 은 specific, generic 금지.
- description 은 operational 의미. marketing copy 금지.
- primary action: 데스크탑 top-right, tablet 공간 부족 시 action menu.

## 9.3 Dashboard page

monitoring/decision support 용도. 모든 지표 덤프 금지.

Required sections:
1. KPI summary row
2. Main trend chart or operational queue
3. Breakdown table/list
4. Recent activity or exceptions

Rules:
- KPI card: white + border.
- Trend color minimal.
- semantic color 는 delta/status 에만.
- date range control 항상.
- loading 은 skeleton card + chart skeleton.

## 9.4 List/index page

Required:
1. PageHeader
2. Toolbar (search/filter/saved views)
3. DataTable
4. Pagination or infinite loading
5. Empty/error/loading states
6. Bulk action bar (row selection 있을 때만)

## 9.5 Detail page

Required:
1. PageHeader (object id/status)
2. Summary card
3. Detail section grouped by meaning
4. Activity/audit/log (schema 지원 시)
5. Related records table
6. Action button (permission 존중)

## 9.6 Create/edit page

Default:
- Drawer/Sheet — lightweight create/edit
- Full page — complex multi-section form
- Modal — short confirmation-like edit 만

Rules:
- 복잡 multi-step form 을 small modal 안에 절대 금지.
- meaningful input 손실 가능하면 unsaved changes warning.
- required field 명시.
- validation error 는 field inline + summary (form 길면).
