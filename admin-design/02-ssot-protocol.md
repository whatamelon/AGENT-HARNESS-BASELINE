---
slug: ssot-protocol
tier: 1
applies_to: [all]
must:
  - read_index_md_before_generating_files
  - inspect_existing_repo
  - apply_default_stack_only_where_no_stronger_standard
  - build_admin_primitives_before_feature_pages
  - run_typecheck_lint_build_tests_when_available
  - log_assumptions_in_final_report
  - create_ssot_attestation_before_first_edit
must_not:
  - ask_user_to_choose_between_design_alternatives
  - fake_audit_log_or_data
  - skip_attestation_emit
cross_ref: [00-non-negotiable, 01-stack, 17-llm-algorithm, 18-acceptance-prompt-contracts]
attestation_required: true
verifier_probes:
  - id: attestation-exists
    layer: L2
    rule: ".admin-build/runs/<latest>/ssot_attestation.json must exist before any admin route file is created or edited"
  - id: attestation-section-coverage
    layer: L2
    rule: "every changed admin file must map to >=1 loaded_section in attestation.task_to_section_map"
---

# 2. Source-of-Truth Architecture for Coding LLMs

## 2.1 How the coding agent should use this document

본 문서를 implementation 동안 영구 참조한다.

Required behavior:

1. 파일 생성 전 본 문서를 읽는다.
2. 기존 repo 구조 inspect.
3. target framework, routing, data fetching, auth, DB schema, available component 식별.
4. 본 문서의 default stack 은 프로젝트가 더 강한 기존 표준 없는 곳에만 적용.
5. feature page 전에 재사용 admin primitive 부터 build.
6. feature page 는 동일 shell/page/table/form/state/RBAC pattern 으로.
7. 가능하면 typecheck/lint/build/test 실행.
8. final response 전에 error fix.
9. final report 에 완료 페이지, 생성 component, assumption, 미해결 manual decision (불가피한 경우만) 명시.

## 2.2 Missing information policy

prompt 가 detail 누락 시 다음 default 적용 (질문 금지):

| Missing input | Default action |
|---|---|
| Primary color | brand 미제공 시 neutral black `--primary` |
| Domain copy | precise, non-marketing 어드민 카피 |
| Permissions | 보수적 permission 상수 + privileged action hide |
| Pagination size | 25 default, options 10/25/50/100 |
| Table density | 40px row default; data-heavy 면 compact 제공 |
| Sort | created_at desc 가능하면, 아니면 primary key desc |
| Date range | analytics=Last 30 days, master data=all-time |
| Empty state CTA | role 에 create permission 있을 때만 |
| Export | 명시 요청 없으면 CSV 만 |
| Deletion | schema 가 soft delete 지원 시 soft, 아니면 destructive confirm |
| Audit log | audit table 있으면 표시, 없으면 omit (fake 금지) |

## 2.3 Assumption logging

design alternative 사이에서 user 에게 선택 요구하지 않는다. safest default 결정하고 final report 에 기록.

Example final report section:

```md
## Assumptions Applied
- Used neutral black as primary because no brand color was provided.
- Used TanStack Table instead of AG Grid because required features did not include pivoting, row grouping, master/detail, or enterprise Excel export.
- Created route-level permission constants from the provided role list because no existing RBAC helper was present.
```

## 2.4 Attestation 의무 (v2 추가)

**모든 어드민 코드 생성·수정 전 `.admin-build/runs/<ts>/ssot_attestation.json` 생성.** PreToolUse hook 이 파일 부재 시 Edit/Write **deny**.

```json
{
  "ssot_version": "admin-design@1.0.0",
  "manifest_hash": "sha256:...",
  "loaded_sections": [
    {"file": "00-non-negotiable.md", "sha256": "..."},
    {"file": "04-tokens.md", "sha256": "..."}
  ],
  "task_to_section_map": {
    "orders-list-page": ["09-tables.md", "07-states.md", "12-rbac.md"]
  },
  "local_override_applied": "admin/admin-design/local.md@sha256:...",
  "exceptions": [],
  "worker_id": "lane-table",
  "agent_cli": "claude-opus-4-7"
}
```

verifier 가 git diff vs `task_to_section_map` 대조. 매핑 누락 파일 수정 시 fail.
