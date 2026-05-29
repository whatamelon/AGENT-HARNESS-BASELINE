---
slug: routing-data
tier: 1
applies_to: [routing, server-state]
must:
  - tanstack_router_for_new_spa
  - tanstack_query_for_server_state
  - structured_query_keys
  - search_params_validated
  - invalidate_exact_queries_after_mutation
must_not:
  - global_block_ui_for_background_refetch
  - unbounded_fetch
  - skip_route_permission_check
cross_ref: [00-non-negotiable, 09-tables, 10-forms, 12-rbac]
verifier_probes:
  - id: structured-query-keys
    layer: L2
    rule: "every feature module exports a Keys factory (e.g. ordersKeys.all/lists/list/detail) — no string-only useQuery keys"
  - id: route-permission-check
    layer: L2
    rule: "protected route definitions must reference RouteMeta.requiredPermission and a PermissionGate or beforeLoad guard"
  - id: validated-search-params
    layer: L2
    rule: "list route uses validateSearch (or zod parse) for search params"
---

# 14. Navigation, Routing, URL State

## 14.1 Default router

신규 React SPA 어드민: **TanStack Router**.

이유:
- type-safe route
- 강력한 search param 처리
- URL-based table/filter state
- TanStack Query/Table 패턴과 통합

## 14.2 Route structure

```txt
/login
/
/dashboard
/{domain}
/{domain}/new
/{domain}/$id
/{domain}/$id/edit
/settings
/settings/users
/settings/roles
/audit-logs
```

## 14.3 Route metadata

protected route 정의:

```ts
type RouteMeta = {
  title: string
  requiredPermission?: Permission
  navGroup?: string
  showInSidebar?: boolean
}
```

## 14.4 Search params

가능하면 list state 모두 search params.

```txt
/orders?q=refund&page=2&pageSize=25&status=pending&sort=created_at&order=desc
```

Rules:
- search params validated.
- unknown param safe fallback.
- URL shareable.
- back/forward 동작.

---

# 15. Server State and Data Fetching

## 15.1 Default

TanStack Query.

## 15.2 Query key policy

structured key:

```ts
const ordersKeys = {
  all: ["orders"] as const,
  lists: () => [...ordersKeys.all, "list"] as const,
  list: (params: OrdersListParams) => [...ordersKeys.lists(), params] as const,
  detail: (id: string) => [...ordersKeys.all, "detail", id] as const,
}
```

## 15.3 Query behavior

- paginated table: `placeholderData` or previous data (project standard 허용 시).
- 초기 load: skeleton.
- background refetch: subtle refreshing indicator.
- background refetch 가 UI globally block 금지.
- mutation 후 exact affected query invalidate.

## 15.4 Error handling

- API error → user-safe message.
- Auth error → redirect or forbidden.
- Validation error → field mapping.
- Unknown error → generic + optional trace ID.
