---
slug: local-override-template
role: template
description: repo `admin/admin-design/local.md` 작성 템플릿. Tier 2 — 추가/구체화만, 완화 X.
copy_to: "<repo>/admin/admin-design/local.md"
---

# Local Override Template

repo 별 도메인·브랜드·DB 특수성을 본 파일에 기록. global SSOT 의 Tier 0 rule 은 **절대 override 불가**.

## 1. Project meta

```yaml
project:
  name: bbakcar-web
  repo: whatamelon/bbakcha (subtree: bbakcar-web)
  framework: nextjs-14-app-router
  db: supabase-postgres
  auth: supabase-auth + custom session
  package_manager: pnpm
```

## 2. Brand primary color (allowed override)

global default 는 neutral black. 브랜드 색이 있을 때만 override:

```yaml
brand:
  primary_hsl: "5 90% 55%"   # 예: 빡차 reddish
  primary_foreground_hsl: "0 0% 98%"
  rationale: "기존 marketing site 와 톤 일치. logo + CTA 만 사용."
```

## 3. Allowed English labels (no-decorative-eyebrow 글로벌 룰 호환)

```yaml
allow_english_labels:
  - "VIN"          # 차량 식별번호
  - "OBD"          # 진단 코드
  - "CRM"
  - "VIP"
```

## 4. Domain-specific status enums (추가만)

```yaml
domain_status_enums:
  vehicles:
    - draft
    - submitted
    - approved
    - active
    - hidden
    - rejected
  test_drives:
    - requested
    - confirmed
    - in_progress
    - completed
    - cancelled
```

각 status 는 `StatusBadge` tone 매핑 필수 (`17-status` 참조).

## 5. Domain DB schema reference

```yaml
db_schema_files:
  - bbakcar-web/supabase/migrations/
  - bbakcar-web/src/types/database.types.ts
critical_tables:
  - vehicles
  - vehicle_catalog
  - test_drives
  - consultations
  - app_users
  - audit_logs
```

## 6. Roles + permissions (action-based)

```yaml
roles:
  - owner
  - admin
  - operator
  - analyst
  - viewer
permissions:
  vehicles: [read, create, update, delete, approve, hide]
  test_drives: [read, create, update, cancel, complete]
  consultations: [read, update, assign, complete]
  users: [read, invite, update, deactivate]
  audit: [read, export]
  settings: [manage]
```

## 7. Forbidden 위반 거부 (Tier 0 / Tier 1 완화 시도는 모두 reject)

다음 시도는 절대 등록 불가:

- dark mode enable
- skip loading/empty/error state
- primary tint card background
- AG Grid Enterprise without license decision
- expose service_role in browser
- mock data in production
- fake audit log

## 8. 추가 verifier probe (project-specific)

global checklist 에 추가하는 project probe:

```yaml
extra_probes:
  - id: vehicles-source-type-enum
    layer: L2
    rule: "vehicles.source_type ∈ {direct_purchase, dealer, consignment} only — HARNESS bbakcar.vehicle-source.v1"
  - id: bbakcar-rbac-org-isolation
    layer: L3
    rule: "every vehicles.read query must filter by organization_id matching session.org_id"
  # 2026-05-28 강화 — list↔detail 페어링 + list 4종 의무
  - id: every-list-has-detail
    layer: L2
    severity: fatal
    rule: "every /(protected)/{domain}/page.tsx must have /(protected)/{domain}/[id]/page.tsx"
  - id: list-page-4-required
    layer: L2
    severity: error
    rule: "list page renders DataTable + FilterBar + PaginationBar + Sortable columns (all 4)"
```
