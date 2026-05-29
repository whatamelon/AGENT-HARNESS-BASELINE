# Phase 04 — Execute

APPROVED plan 을 lane 별로 분산 execute.

## Worker 디스패치

```bash
# tmux + omx team 가 정본 (글로벌 룰 tmux-agents.md)
OMX_TEAM_WORKER_CLI_MAP=claude,codex,claude,codex,claude omx team 5:executor \
  "Build admin per plan.md. lane assignment in work_lanes.yaml"
```

각 worker:
1. `cd <worktree>/lane-<name>/`
2. SSOT attestation 자기 lane 으로 emit (`admin-build attest --task <kind> --worker lane-<name>`)
3. plan 의 자기 lane 작업 수행
4. lane log 적재 (`.admin-build/runs/<ts>/worker-logs/<lane>.jsonl`)

## Merge queue (2026-05-28 갱신 — list↔detail 페어링 강제)

```
1. shell           (app/(protected)/layout.tsx, components/admin/shell/**)
2. rbac            (lib/auth/**, middleware.ts, supabase/migrations/**)
3. tokens          (styles/globals.css, components.json, brand override)
4. queries+services (src/queries/**, src/services/**, src/lib/validations/**)
5. actions         (src/actions/** — audit_logs 의무)
6. tables-list     (app/(protected)/<domain>/page.tsx + _components/*-table.tsx)
                   필수 4종: DataTable + FilterBar + PaginationBar + Sort
7. tables-detail   ★ 필수 lane ★ — list 1개당 detail 1개 1:1
                   app/(protected)/<domain>/[id]/page.tsx
                   PageHeader + Summary + Detail + ActivityTimeline + NotFoundState
8. forms           (app/(protected)/<domain>/{new,[id]/edit}/page.tsx + 컴포넌트)
9. carmanager      (도메인 hero dashboard)
10. command-pal    (⌘K)
11. tests          (verifier configs, RBAC fixture)
```

**Rule**: 6 + 7 은 한 lane 단위로 묶어서 처리 — list page commit 할 때 detail page 도 같이. detail 누락 list page 는 verifier `detail-page-paired-with-list` probe fail.

orchestrator 가 lane worktree 의 patch 를 순서대로 main branch 에 cherry-pick. 충돌 시 자동 repair prompt → 해당 lane worker 에 회귀.

## list↔detail 1:1 페어링 강제

P3 critic 단계에서 plan.md 의 route inventory 검사:
- 모든 `list-page` row 에 대응하는 `detail-page` row 존재 확인
- 누락 시 critic REJECT → planner 재진입

P5 verifier `detail-page-paired-with-list` probe 가 git checkout 후 file 시스템 검증:
- `app/(protected)/<domain>/page.tsx` 발견 → `app/(protected)/<domain>/[id]/page.tsx` 필수
- 미존재 시 fatal

## 진행 기록

- 각 lane 완료 시 `.admin-build/runs/<ts>/changed-files-<lane>.txt` 적재
- merge 시 `changed-files.txt` 누적

## stop 조건

- 모든 lane 완료
- 또는 lane 별 budget 소진
- 또는 verifier 가 budget 내 통과 못 함
