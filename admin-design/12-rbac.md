---
slug: rbac
tier: 1
applies_to: [all, security-boundary]
must:
  - action_based_permissions
  - centralize_permission_logic
  - server_side_enforcement_for_every_privileged_op
  - permission_gate_for_ui_visibility
  - hide_vs_disable_correctly
  - supabase_rls_enabled_for_exposed_tables
must_not:
  - frontend_only_security
  - hardcode_superuser_bypass_in_ui_components
  - expose_service_role_secret_in_browser
  - leak_sensitive_data_in_forbidden_state
cross_ref: [00-non-negotiable, 06-shell-pages, 07-states, 11-routing-data, 18-acceptance-prompt-contracts]
verifier_probes:
  - id: server-enforcement-paired
    layer: L3
    rule: "every action with PermissionGate in UI must have a paired server enforcement (API route/server action/Edge Function/RLS policy) — verified by RBAC runtime fixture"
    fixtures: [owner, ops, viewer, forbidden]
  - id: no-service-role-in-browser
    layer: L1
    grep: "SUPABASE_SERVICE_ROLE_KEY|service_role|SERVICE_ROLE"
    forbid_paths: [src/components/**, src/features/**/components/**, app/**/page.tsx, app/**/layout.tsx, public/**]
  - id: forbidden-state-no-leak
    layer: L3
    rule: "ForbiddenState rendered without object details (no id/name/email leaked when role lacks read permission)"
---

# 16. RBAC, Auth, and Security Boundary

## 16.1 RBAC principle

UI permission check 는 UX 향상이지 security 아님.

모든 sensitive operation 은 최소 한 backend boundary 에서 enforce:

```txt
API route / backend service / server action / Edge Function / database RLS / stored procedure
```

## 16.2 Permission model

action-based:

```ts
type Permission =
  | "orders.read"
  | "orders.create"
  | "orders.update"
  | "orders.delete"
  | "orders.refund"
  | "users.read"
  | "users.invite"
  | "settings.manage"
```

Role 은 permission collection:

```ts
type Role = "owner" | "admin" | "manager" | "operator" | "analyst" | "viewer"
```

UI component 에 superuser bypass hardcode 금지. permission logic 중앙화.

## 16.3 PermissionGate

```tsx
<PermissionGate permission="orders.refund">
  <Button>Refund</Button>
</PermissionGate>
```

or:

```ts
const canRefund = useCan("orders.refund")
```

## 16.4 Hide vs disable

| Case | Behavior |
|---|---|
| User should not know action exists | Hide |
| User knows action exists but currently cannot perform | Disable + tooltip/explanation |
| Permission missing for page | ForbiddenState |
| Permission missing for field | Read-only or hidden (민감도 따라) |

## 16.5 Supabase-specific

Supabase 사용 시:

- exposed table 에 RLS enable.
- publishable/anon key 만 사용, least privilege.
- service role/secret key 를 browser code 에 노출 절대 금지.
- elevated access 가 필요한 admin-only mutation 은 Edge Function/server route/backend service 경유.
- service-role operation 은 narrowly scope + audit.

## 16.6 Audit log contract (v2 추가)

모든 CUD operation 은 `audit_logs` insert (`bbakcha` workspace 컨벤션).

contract: `~/.config/agent-harness-baseline/admin-security/_audit-log-contract.md` 참조.
