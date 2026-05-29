# Phase 03 — Verdict (Critic)

Critic agent 가 plan.md 를 SSOT 와 비교 검토. 위반 1개라도 발견 시 REJECT.

## 검토 룰

1. **Tier 0 위반 여부** — plan 의 어느 항목도 `00-non-negotiable.md` 위반 X.
2. **누락 state** — list-page 마다 loading/empty/error/forbidden/success 5종 모두 포함.
3. **누락 permission gate** — protected route 마다 server enforcement layer 명시.
4. **누락 audit_logs** — CUD action 마다 audit insert.
5. **token 위반** — primary tint card / arbitrary hex / dark variant 없음.
6. **AG Grid 정당화** — 사용 시 §12.7 조건 충족 + assumption 기록.
7. **secret leak** — service_role/secret 이 client path 에 없음.
8. **viewport coverage** — 5종 viewport 검증 계획 포함.
9. **RBAC fixture** — owner/ops/viewer/forbidden 4종 모두 verifier 단계 포함.
10. **worker lane 중복** — 동일 파일 두 lane 이 own 하지 않음.

## 강화 룰 (2026-05-28 — list/detail 누락 사고 재발 방지)

11. **list-page 4 의무 명시** — 모든 list-page row 의 plan description 에 다음 4 컴포넌트 명시:
    - `DataTable` (TanStack Table abstraction, native `<table>` 금지)
    - `DataToolbar` 또는 `FilterBar` (검색 input + 최소 1 chip)
    - `PaginationLinks` 또는 `PaginationBar` (server pagination)
    - **Sortable column** (URL `sort`/`order` param sync)

    하나라도 누락 = REJECT.

12. **list ↔ detail 1:1 페어링** — 모든 `list-page` row 에 대응하는 `detail-page` row 존재 검사. 누락 시 REJECT. 예외:
    - `dashboard`, `settings`, `hub_page`, `sub_list_terminal` (audit/match-queue 등) 만 detail 면제.
    - 면제 시 plan 에 명시적 sub_list_terminal 또는 hub_page 라벨링.

13. **detail-page 7 의무 명시** — 모든 detail-page row 의 plan 에 다음 명시:
    - `PageHeader` (title + breadcrumb back-to-list)
    - Section: 요약
    - Section: 상세
    - Activity timeline (audit_logs 있을 때 — W7 inspector)
    - Related records (있을 때)
    - `NotFoundState` boundary (`notFound()` from next/navigation)
    - `ForbiddenState` boundary (RBAC fail)

14. **lane: detail 누락 금지** — worker lane plan §5 에서 `detail` lane 이 존재해야. 미존재 = REJECT (P4 execute 가 detail 건너뛸 위험).

15. **routes.json emit 계획** — P4 끝나기 전 `.admin-build/routes.json` 생성 의무. 모든 list/detail/form/dashboard route 가 type 분류 포함.

16. **wow point 약속과 구현 매칭** — local.md §8 의 must (W1-W5) 모두 plan §6 에 실 구현 lane assignment 포함. should/could 우선순위 명시.

## 출력

```yaml
verdict: APPROVE | REJECT
findings:
  - severity: fatal | error | warn
    rule: 09-tables.md §12.2 + frontmatter must
    where: plan.md §2.routes[/admin/orders]
    fix: "DataToolbar + PaginationLinks + sortable column 추가"
revised_plan_required: true | false
```

`REJECT` 면 Planner 가 fix 반영 후 phase 02 재진입. APPROVE 까지 반복 (max 5 iter — 외부 orchestrator 가 budget 관리).

**iter 5 도달 = critical block** — Planner 와 critic 사이 alignment 실패. 사용자 alert.
