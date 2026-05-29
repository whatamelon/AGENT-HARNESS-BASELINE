---
slug: forms
tier: 1
applies_to: [form-page, create-edit]
must:
  - react_hook_form_plus_zod
  - group_fields_by_meaning
  - inline_validation_close_to_field
  - pending_state_disable_submit
  - prevent_duplicate_submission
  - server_side_validation_independent_of_client
must_not:
  - complex_multistep_form_in_modal
  - trust_client_validation_as_security
  - silent_failure_on_mutation
cross_ref: [00-non-negotiable, 06-shell-pages, 07-states, 11-routing-data, 12-rbac, 13-feedback-overlay]
verifier_probes:
  - id: zod-schema-presence
    layer: L2
    rule: "form components must import a zod schema (z.object) for resolver"
  - id: submit-disabled-while-pending
    layer: L3
    rule: "submit button has disabled={isPending} (or equivalent)"
  - id: server-error-mapping
    layer: L2
    rule: "mutation onError must map server errors to user-safe messages (no raw 500/stack)"
---

# 13. Forms

## 13.1 Default form stack

```txt
React Hook Form + Zod + shadcn/ui form/input/select/textarea components
```

## 13.2 Form principles

- 폼은 operational workflow. visual decoration X.
- field 는 meaning 별 group.
- required 필드 명확.
- validation error 는 field 가까이.
- 긴 form 은 section navigation 또는 sticky action footer.
- mutation 은 pending state 표시 + duplicate submit 방지.

## 13.3 Field anatomy

```txt
label
description/help text
control
validation message
optional/required signal
disabled/read-only state
```

## 13.4 Form layout

| Form type | Layout |
|---|---|
| Short create/edit | Drawer/Sheet, max width 480-640px |
| Medium entity form | Full page or wide drawer, grouped sections |
| Long/compliance form | Full page, sticky footer, section navigation |
| Destructive confirmation | AlertDialog (form page X) |
| Quick inline edit | Table cell/edit popover, low risk 만 |

## 13.5 Validation

1. client-side: Zod
2. server-side: API/DB constraint
3. visual: inline error

client validation 을 security 로 신뢰 금지.

## 13.6 Mutation UX

submit 시:
1. submit 버튼 disable.
2. spinner/loading text 표시.
3. duplicate submission 방지.
4. success: toast + drawer 닫기/navigate/cache update.
5. error: inline 또는 form-level error.
6. TanStack Query cache invalidate/update.
