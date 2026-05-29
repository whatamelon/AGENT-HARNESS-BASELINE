---
slug: states
tier: 1
applies_to: [all]
must:
  - implement_loading_empty_error_forbidden_success_at_minimum
  - skeleton_shaped_like_final_content
  - empty_state_answers_what_why_next
  - forbidden_state_no_sensitive_data_leak
  - destructive_confirm_for_irreversible_actions
must_not:
  - full_page_spinner_unless_app_booting
  - raw_stack_trace_in_production_ui
  - empty_state_create_cta_without_permission
  - typed_confirmation_skipped_for_high_risk
cross_ref: [00-non-negotiable, 06-shell-pages, 09-tables, 12-rbac, 13-feedback-overlay]
verifier_probes:
  - id: state-taxonomy-min-set
    layer: L3
    rule: "every list-page route renders loading|empty|error|forbidden|success (fixture-driven Playwright)"
    fixtures: [empty-data, error-500, forbidden-role, happy-path]
  - id: confirm-for-destructive
    layer: L2
    rule: "every onClick handler bound to a delete/refund/cancel/destroy mutation must wrap in ConfirmDialog"
  - id: no-stack-trace-in-ui
    layer: L1
    grep: "\\.stack\\b|error\\.stack|err\\.stack"
    allow_paths: [lib/errors/, debug/, dev/]
---

# 10. State Taxonomy

## 10.1 Required state model

모든 feature 가 UI 를 다음 state 에 매핑:

| State | Meaning | UI pattern |
|---|---|---|
| `idle` | Ready for interaction | Normal surface |
| `loading` | Initial data loading | Skeleton, not spinner-only |
| `refreshing` | Background refetch | Subtle progress/toolbar indicator |
| `processing` | Mutation in progress | Disable affected controls + spinner |
| `confirm` | Needs user confirmation | AlertDialog/ConfirmDialog |
| `success` | Mutation completed | Toast + updated UI |
| `complete` | Domain process completed | StatusBadge + optional timestamp |
| `empty` | No data exists | EmptyState with permission-aware CTA |
| `error` | Recoverable error | ErrorState with retry |
| `warning` | Risk but not blocked | Inline warning/banner |
| `forbidden` | Permission denied | ForbiddenState, no sensitive data |
| `notFound` | Object missing | NotFoundState |
| `disabled` | Action unavailable | Disabled control + explanation |
| `partial` | Partially completed | Progress + neutral indicator |
| `failed` | Domain operation failed | Error badge + retry/action |
| `archived` | Record inactive/archived | Muted badge/surface |
| `scheduled` | Future operation | Neutral badge + timestamp |
| `draft` | Not finalized | Muted badge |

## 10.2 State component rules

### Loading
- skeleton shape = final content.
- full-page spinner 는 app 부팅 시에만.
- table loading 은 skeleton row, 동일 column.

### Empty
3개 답해야:
1. 무엇이 empty?
2. 왜 empty 일 수 있나?
3. 다음 행동?

create permission 없으면 create CTA 표시 금지.

### Error
포함:
- concise title
- explanation
- retry button (retryable 한 경우)
- support/debug detail 은 disclosure 안에

raw stack trace 노출 금지.

### Forbidden
sensitive object detail 노출 금지.

```txt
You do not have permission to view this resource.
```

또는 localized equivalent.

### Confirm
모든 destructive/irreversible action 에 confirmation 필수.

Dialog 포함:
- action name
- target object name/id
- consequence
- destructive button
- cancel button

high-risk action 은 **typed confirmation** 요구.
