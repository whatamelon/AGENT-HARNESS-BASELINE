---
slug: feedback-overlay
tier: 1
applies_to: [feedback, modal, drawer, popover]
must:
  - toast_for_transient_feedback
  - banner_for_persistent_page_level_condition
  - modal_for_confirmation_or_short_focused_task
  - drawer_for_short_to_medium_form_and_row_detail
  - destructive_action_visually_separated
must_not:
  - toast_for_must_read_information
  - modal_for_large_data_table_or_long_form
  - complex_form_in_popover
  - destructive_action_hidden_in_dropdown_without_confirm
cross_ref: [00-non-negotiable, 07-states, 10-forms, 17-status]
verifier_probes:
  - id: no-complex-form-in-modal
    layer: L2
    rule: "Dialog/Modal children must not contain >3 form inputs unless component is AlertDialog"
  - id: destructive-confirmed
    layer: L2
    rule: "any DropdownMenuItem with className containing 'destructive' must trigger ConfirmDialog"
---

# 17. Status and Badges

## 17.1 StatusBadge component

모든 status label 은 `StatusBadge` 경유.

```ts
type StatusTone =
  | "neutral"
  | "info"
  | "success"
  | "warning"
  | "danger"
  | "muted"
```

## 17.2 Visual rules

Default:

```txt
border + white/gray background + small text
```

- semantic accent 는 small dot, border, text accent.
- saturated filled badge 회피 (destructive/danger 필수 케이스 예외).
- 임의 색 생성 금지.

## 17.3 Common status mapping

| Domain status | Tone |
|---|---|
| active | success or neutral with dot |
| inactive | muted |
| draft | muted |
| pending | warning or neutral |
| processing | info |
| completed | success |
| failed | danger |
| canceled | muted/danger (도메인 따라) |
| archived | muted |
| scheduled | info/neutral |
| blocked | danger |
| needs_review | warning |

---

# 18. Feedback Components

## 18.1 Toasts

transient feedback.

- Success: mutation 완료 후.
- Error: mutation 실패 시.
- Warning: action 부분 완료.
- 진행 전 반드시 읽어야 할 정보 → toast 사용 금지.

## 18.2 Banners / Alerts

persistent page-level condition:
- payment provider disconnected
- sync failed
- read-only mode
- missing configuration
- partial outage
- permission limitation

## 18.3 Progress

import/export/batch/sync/multi-step/long-running 에 progress indicator.

unknown progress 면 indeterminate + status text.

---

# 19. Modals, Drawers, Popovers

## 19.1 Modal rules

사용:
- confirmation
- short focused task
- small form
- blocking decision

금지:
- large data table
- long form
- complex multi-step workflow
- analytics dashboard

## 19.2 Drawer/sheet rules

사용:
- create/edit short~medium form
- row detail preview
- tablet filter
- contextual setting

Widths:

```txt
sm: 420px
md: 560px
lg: 720px
xl: 960px
```

## 19.3 Popover rules

사용:
- lightweight filter
- date range picker
- quick setting
- small inline explanation

complex form 또는 long content 금지.

## 19.4 Dropdown menu rules

secondary action 용.

- 데스크탑에서 primary action 을 dropdown 안에 숨기지 않는다.
- destructive action 은 분리 + 시각 표시.
- dangerous action 은 confirm 필수.
