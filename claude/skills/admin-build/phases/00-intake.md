# Phase 00 — Intake

intake 수집. 누락 input 은 SSOT default 적용 (`02-ssot-protocol.md §2.2`), 사용자에게 design 질문 금지.

## 필수 field

| field | required | example |
|---|---|---|
| `goal` | yes | "주문 관리 어드민" |
| `domain` | yes | `erp/commerce/finance/crm/marketing/internal-tool` |
| `admin_users` | yes | persona list |
| `roles_permissions` | yes | role → permission[] map |
| `db_schema_files` | yes | path list |
| `required_pages` | yes | route list |
| `required_actions` | yes | list/detail/create/update/delete/approve 등 |
| `auth_rbac.provider` | yes | "supabase-auth", "auth0", etc |
| `auth_rbac.server_enforcement` | yes | server_action / api_route / rls_policy / edge_function 중 1+ |
| `brand.primary_hsl` | no | 미제공 시 neutral black |
| `project_meta.framework` | yes | nextjs-14-app-router, vite-react, etc |

## 산출물

`.admin-build/runs/<ts>/input.yaml` 에 normalize 한 intake 저장.

## 누락 처리

| Missing | Default |
|---|---|
| `brand.primary_hsl` | neutral black `0 0% 9%` |
| `pagination_size` | 25 |
| `sort_default` | `created_at desc` (있을 때) |
| `audit_log_table` | 있으면 표시, 없으면 omit (fake 금지) |
| `export_format` | CSV |
| `deletion_strategy` | soft (schema 지원) / destructive confirm |

미정 사항 모두 `.admin-build/runs/<ts>/assumptions.md` 에 기록.

## 거부

다음 intake 는 거부:
- `dark_mode_required: true` — Tier 0 위반
- `mock_data_ok: true` — Tier 0 위반
- `frontend_only_security: true` — Tier 0 위반
