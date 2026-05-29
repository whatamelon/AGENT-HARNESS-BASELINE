---
slug: stack
tier: 1
applies_to: [new-project, repo-bootstrap]
must:
  - use_default_stack_unless_repo_forces_otherwise
  - preserve_existing_production_grade_framework
  - apply_token_state_taxonomy_even_in_existing_projects
must_not:
  - rewrite_routing_or_build_without_request
  - install_discouraged_default_libraries
  - mix_visual_languages
discouraged_defaults:
  - antd
  - mui
  - chakra
  - bootstrap
  - mantine
  - polaris
  - carbon
  - salt
  - ag-charts-by-default
  - ag-grid-enterprise-by-accident
  - base-ui-radix-react-aria-all-at-once
  - dark-mode
  - theme-switcher
  - marketing-style
cross_ref: [00-non-negotiable, 02-ssot-protocol, 04-tokens, 09-tables, 14-dashboard-analytics]
verifier_probes:
  - id: no-discouraged-deps
    layer: L1
    grep: "@ant-design|@mui|@chakra-ui|bootstrap|@mantine|@shopify/polaris|@carbon/react|@salt-ds"
    allow: "explicit override in admin/admin-design/local.md with reason"
---

# 1. Recommended Production Stack

## 1.1 Default stack for a new admin

신규 어드민 기본값. 기존 repo 가 다른 선택을 강제하지 않을 때.

```txt
Runtime/App:        React + TypeScript SPA
Build:              Vite or existing build system
Routing:            TanStack Router
Server state:       TanStack Query
UI foundation:      shadcn/ui
Styling:            Tailwind CSS + CSS variables
Primitive layer:    Radix UI via shadcn/ui
Forms:              React Hook Form + Zod
Tables:             TanStack Table + TanStack Virtual
Heavy grid:         AG Grid only after license/feature decision
Dashboard/charts:   Tremor; Recharts directly when needed
Icons:              lucide-react
Toast:              Sonner or shadcn toast equivalent
Date handling:      date-fns or project standard
Auth/RBAC:          project auth + server-side permission enforcement
Backend boundary:   server action / API route / Edge Function / backend service
Database:           use provided schema; never invent hidden schema
```

## 1.2 Existing project adaptation

기존 코드베이스 안에서 구현 시:

- production-grade framework 면 유지.
- 명시 요청 없으면 routing/build system 재작성 금지.
- 그래도 본 문서의 visual language, token, component, state taxonomy, page pattern 적용.
- 기존 UI library 와 visual language mix 금지. 대상 어드민 surface 를 본 system 으로 migrate 하거나 legacy 를 호환 admin component 로 wrap.

## 1.3 Explicitly discouraged defaults

기본 도입 금지:

- Ant Design, MUI, Chakra, Bootstrap, Mantine, Polaris, Carbon, Salt — primary component library 로 사용 금지
- AG Charts — AG Grid Enterprise chart integration 명시 요청 시에만
- AG Grid Enterprise — licensing/feature need 명확할 때만
- Base UI + Radix + React Aria 동시 사용
- Dark mode, theme switcher, gradient-heavy SaaS style, colorful card backgrounds, marketing-site visual effects

local.md 의 Tier 2 override 도 위 목록 완화 불가 (해석: "기본 도입 금지" 는 강제 도입이 아니라 default 만 막음 — 프로젝트가 명시 사유로 채택하면 OK).
