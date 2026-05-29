---
slug: non-negotiable
tier: 0
applies_to: [all]
override: forbidden
must:
  - light_mode_only
  - monochrome_first
  - primary_injected_not_baked_in
  - shadcn_radix_tailwind_first
  - single_primitive_layer
  - tanstack_table_first
  - tremor_for_dashboard
  - all_states_implemented
  - url_preserves_list_state
  - rbac_server_enforced
  - no_demo_only_ui
  - infer_safe_defaults_continue
must_not:
  - dark_mode_classes_or_toggle
  - colored_card_backgrounds
  - rainbow_badges
  - multi_primitive_libraries_by_default
  - ag_grid_without_license_justification
  - mock_data_in_production_pages
  - frontend_only_security
  - stop_to_ask_design_questions
cross_ref: [01-stack, 02-ssot-protocol, 04-tokens, 12-rbac, 18-acceptance-prompt-contracts]
verifier_probes:
  - id: no-dark-class
    layer: L1
    grep: "dark:|\\.dark\\b|className=\"dark"
    expect: 0
  - id: no-arbitrary-hex
    layer: L1
    grep: "#[0-9a-fA-F]{6}|#[0-9a-fA-F]{3}\\b"
    allow_paths: [styles/globals.css, theme.ts, tokens.ts, components.json]
  - id: ag-grid-enterprise-justification
    layer: L2
    rule: "if 'ag-grid-enterprise' in deps, /admin-build/runs/*/assumptions.md must contain 'AG Grid Enterprise 정당화'"
  - id: state-taxonomy-min-5
    layer: L2+L3
    rule: "every list-page renders loading|empty|error|forbidden|success"
---

# Tier 0 — Non-Negotiable Rules

Coding LLM MUST follow. 어떤 product prompt 도 override 불가.

1. **Light mode only.** Background 항상 white. dark mode, theme toggle, `dark:` variant, `.dark` class 금지.
2. **Monochrome first.** 모든 layout/card/table/form/border/surface/typography/icon/divider/neutral state 는 white/black/gray 만 기본.
3. **Primary color is injected, not baked in.** Primary 는 CTA, focus ring, selected item, active nav item, 제한적 chart accent 에만. card, page background, table background, 큰 surface 에 primary tint 금지.
4. **shadcn/ui + Tailwind + Radix-first.** shadcn/ui 컴포넌트는 owned source code, Tailwind 로 styling, CSS variable 로 token, Radix primitive 기본 a11y layer.
5. **다중 headless primitive 시스템 기본 설치 금지.** Radix 부터. React Aria 는 특정 advanced a11y 케이스에만. Base UI 는 명시 채택 시에만.
6. **TanStack Table first.** 보통-중간 복잡도 테이블은 TanStack Table + TanStack Virtual. AG Grid 는 license cost 정당화될 때만.
7. **Tremor for dashboard/chart.** Tremor 가 부족할 때만 Recharts 직접. AG Charts 기본 금지.
8. **모든 페이지는 모든 state 구현.** loading/empty/error/forbidden/notFound/optimistic/success/warning/destructive-confirm/retry 필수.
9. **모든 list page 는 URL 에 state 저장.** search/filter/sort/pagination/date range/view mode/column visibility 모두 route search param.
10. **Frontend RBAC 는 security 아님.** UI hide/disable 은 허용. 모든 privileged operation 은 server-side 또는 DB policy/server function 으로 enforce.
11. **No demo-only UI.** mock data, TODO placeholder, fake API, unused skeleton page 잔존 금지 (사용자가 prototype 명시 요청 시 예외).
12. **정보 부족 시 safe default 추론 + 진행.** design 질문하려고 implementation 멈추지 않는다. assumption 은 final report 에 기록.

## 위반 시

verifier L1/L2 에서 즉시 fail. `admin-build` orchestrator 가 repair prompt 자동 생성 → 워커에 회귀. budget 소진까지 반복.
