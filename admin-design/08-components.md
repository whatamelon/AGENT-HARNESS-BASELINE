---
slug: components
tier: 1
applies_to: [components]
location: "src/components/admin/"
must:
  - create_missing_components_in_admin_layer_not_adhoc_jsx
  - prefer_shadcn_implementations_for_overlays
  - centralize_status_through_status_badge
  - centralize_permission_through_permission_gate
  # 강화 (2026-05-28) — list/detail 컴포넌트 사용 의무
  - list_page_renders_DataTable_DataToolbar_PaginationLinks_all_three
  - detail_page_renders_PageHeader_DetailShell_or_equivalent_layout
  - filter_chip_or_select_for_every_enum_column_in_list
must_not:
  - rewrite_same_table_logic_per_page
  - duplicate_primitive_libraries
  - native_html_table_in_list_pages   # 항상 DataTable abstraction
  - list_page_without_DataToolbar     # search input + chip 없는 list = REJECT
  - list_page_without_pagination      # 0 결과여도 PaginationLinks shell render
cross_ref: [00-non-negotiable, 06-shell-pages, 09-tables, 10-forms, 12-rbac, 13-feedback-overlay, 14-dashboard-analytics, 18-acceptance-prompt-contracts]
verifier_probes:
  - id: foundation-components-present
    layer: L2
    rule: "AdminShell/SidebarNav/Topbar/Breadcrumbs/Page/PageHeader/Section/EmptyState/ErrorState/ForbiddenState/NotFoundState/LoadingState/ConfirmDialog/StatusBadge/PermissionGate all exported"
  - id: data-components-present
    layer: L2
    rule: "components/admin/data-table/{DataTable,DataToolbar,FilterChip,PaginationLinks} 또는 동등 컴포넌트 모두 존재"
  - id: list-page-uses-data-components
    layer: L2
    rule: "src/app/(protected)/<domain>/page.tsx (list) 가 DataTable + (DataToolbar|FilterBar) + (PaginationLinks|PaginationBar) JSX 모두 import + render"
  - id: detail-page-uses-detail-shell
    layer: L2
    rule: "src/app/(protected)/<domain>/[id]/page.tsx 가 PageHeader + (DetailShell|grid layout) 사용 + (ActivityTimeline import — audit_logs 있을 때)"
---

# 11. Component Inventory

Agent 는 missing component 를 admin layer 안에 생성. ad hoc JSX 반복 금지.

위치:

```txt
src/components/admin/
```

## 11.1 Foundation

```txt
AdminShell
SidebarNav
Topbar
Breadcrumbs
Page
PageHeader
Section
Surface
EmptyState
ErrorState
ForbiddenState
NotFoundState
LoadingState
ConfirmDialog
StatusBadge
PermissionGate
```

## 11.2 Data

```txt
DataTable
DataToolbar
FilterBar
FilterSheet
ColumnVisibilityMenu
DensityToggle
SavedViewTabs
BulkActionBar
PaginationBar
TableSkeleton
DataGridDecisionNotice (optional)
```

## 11.3 Form

```txt
FormShell
FormSection
FieldGroup
FieldDescription
FieldError
FormActions
UnsavedChangesGuard
CreateDrawer
EditDrawer
```

## 11.4 Overlay (shadcn/ui 우선)

```txt
Dialog
AlertDialog
Sheet/Drawer
Popover
DropdownMenu
ContextMenu
Tooltip
CommandMenu
```

## 11.5 Dashboard (Tremor 우선)

```txt
KpiCard
KpiGrid
ChartCard
TrendChart
BreakdownList
MetricDelta
ActivityFeed
ExceptionList
```
