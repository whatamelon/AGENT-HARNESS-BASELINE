---
name: admin-build
description: One-shot production-ready admin builder using Neutral Admin Design System v1.0 SSOT. ralplan → goal/team → 4-layer verifier loop. Use when user requests "어드민 만들어", "/admin-build", "admin scaffold", "back-office one-shot", or builds ERP/commerce/finance/CRM/marketing admin from scratch. SSOT lives at ~/.claude/admin-design/ (symlink). Security gate at ~/.claude/admin-security/. External orchestrator at ~/.config/agent-harness-baseline/admin-build/bin/admin-build.
x-admin-build:
  ssot_root: "~/.claude/admin-design"
  security_root: "~/.claude/admin-security"
  orchestrator: "~/.config/agent-harness-baseline/admin-build/bin/admin-build"
  required_context:
    - admin-design/manifest.json
    - admin-design/index.md
    - admin-design/00-non-negotiable.md
    - admin-design/02-ssot-protocol.md
  required_verifiers:
    - admin-design-verifier (L1 + L2)
    - playwright-smoke (L3)
    - rbac-runtime-check (L3 security)
    - axe + screenshot-matrix (L4)
  max_iterations: 12
  runtime_budget_hours: 12
  worker_lanes: [shell, table, form, modal, rbac, verifier]
---

# /admin-build — One-shot 어드민 builder

## 진입 시 즉시

1. `~/.claude/admin-design/manifest.json` 읽기.
2. `~/.claude/admin-design/index.md` + `00-non-negotiable.md` + `02-ssot-protocol.md` 읽기.
3. user intake yaml 받기 (없으면 `phases/00-intake.md` 가이드 따름).
4. `admin-build attest --task <kind>` 실행 → ssot_attestation.json 생성.
5. attestation 없으면 PreToolUse hook 이 admin route Edit/Write deny — 첫 코드 작업 전 무조건 생성.

## Phase 흐름

```
00-intake     → 입력 수집 (기능/도메인/페르소나/RBAC/DB schema)
01-research   → manifest.task_router 매핑 → 관련 SSOT section lazy load
02-plan       → Planner: 페이지 인벤토리·라우트·권한·DB binding
03-verdict    → Critic: SSOT 위반 식별 → plan 수정. APPROVE 까지 반복
04-execute    → team 디스패치 (lane-isolated worktree, Claude+Codex 혼합)
05-verify     → admin-build verify (L1+L2+L3+L4 + RBAC fixture 4종)
06-finalize   → run artifact 마무리 (assumptions.md, final-verdict.md, screenshots)
```

phase 본문은 `phases/0x-*.md` 참조.

## intake.yaml schema

```yaml
goal: "주문 관리 어드민"
domain: commerce      # erp | commerce | finance | crm | marketing | internal-tool
admin_users:
  - persona: "운영팀"
    count: 30
    primary_action: ["주문 조회", "환불 승인"]
roles_permissions:
  owner: all
  ops: [orders.read, orders.update, refunds.read, refunds.create]
  viewer: [orders.read, refunds.read]
db_schema_files:
  - bbakcar-web/supabase/migrations/
  - bbakcar-web/src/types/database.types.ts
required_pages:
  - /admin/orders
  - /admin/orders/[id]
  - /admin/refunds
required_actions: [list, detail, update, refund]
business_rules:
  - "refund > 100만원 → owner 승인 필요"
auth_rbac:
  provider: supabase-auth
  server_enforcement: server_action + rls_policy
brand:
  primary_hsl: "5 90% 55%"
project_meta:
  framework: nextjs-14-app-router
  package_manager: pnpm
```

## Tier 0 위반 거부

다음 prompt 는 즉시 reject:

- "이번에 다크 모드 켜"
- "mock data 잠시만 쓰자"
- "loading state 스킵해도 됨"
- "service_role 클라이언트에 그냥 노출"
- "RLS 끄고 디버그"
- "AG Grid Enterprise license 없이 도입"

사유 + `~/.claude/admin-design/_exceptions.md` 절차 안내.

## List-page 비협상 3종 (§09-tables §12.9~12.11, 2026-05-29 강화)

generic SaaS 테이블로 흘러가는 것을 막는 list-page 필수 패턴. table lane 디스패치 전 worker inbox 에 명시하고, `admin-build verify` 가 `pk-column-sole-detail-entry` / `sticky-table-header` / `status-filter-colored` / `pk-cell-helper-present` probe 로 강제한다.

1. **PK 단일 진입 (§12.9).** 1번 *데이터* 컬럼 = PK(`id`), `#`+bold+underline (`PkLink`/`pkColumn()` 공유 factory). 상세 이동은 PK 클릭만 — 이름/제목/번호판 등 비-PK 셀은 평문(`<Link>` 금지). (구 `primary_identifier_links_to_detail` = 폐기.)
2. **Sticky 헤더 (§12.10).** DataTable `thead` 는 `sticky top-0 z-10` + opaque bg(`bg-muted` 등, 반투명 금지). 래퍼에 `overflow-hidden` 걸어 sticky 무력화 금지 (스크롤 컨테이너 = AdminShell `<main overflow-y-auto>`).
3. **상태 필터 의미색 (§12.11).** `FilterChip` 은 `tone` 지원 + `paramName==='status'` 면 `toneFor(value)` 자동 색칠(컬러 dot + tint). 흑백 토글만 금지. (status 의미색은 Tier 0 monochrome-first 의 정당 예외.)

## Worker lane 매핑

```yaml
work_lanes:
  shell:    { cli: claude, owns: ["app/(admin)/layout.tsx", "components/admin/shell/**"] }
  table:    { cli: codex,  owns: ["components/admin/data-table/**", "app/(admin)/orders/page.tsx"] }
  form:     { cli: claude, owns: ["components/admin/forms/**", "app/(admin)/orders/[id]/**"] }
  modal:    { cli: codex,  owns: ["components/admin/overlays/**"] }
  rbac:     { cli: claude, owns: ["lib/auth/**", "lib/rbac/**", "middleware.ts", "supabase/migrations/**"], may_touch: ["app/(admin)/**"] }
  verifier: { cli: claude, read_only: true }
```

각 lane = git worktree 분리. merge queue: shell → rbac → tokens → routes → tests.

## 외부 orchestrator 명령

```bash
admin-build attest --task list-page --worker shell --agent claude
admin-build verify --fast        # L1 + L2 only
admin-build verify               # 4 layers (Playwright/axe/screenshot 포함)
admin-build status               # latest run 상태
admin-build replay <run-id>      # 재현 실행
```

## 완료 조건

- L1 + L2 + L3(RBAC fixture 4종) + L4 모두 pass
- `.admin-build/runs/<ts>/final-verdict.md` 에 PASS 기록
- `assumptions.md` 가 intake 누락 input 에 대해 default 결정 모두 기록
- typecheck + build + lint pass

미통과 시 외부 orchestrator 가 repair prompt 생성 → resume session → loop. budget 소진까지 반복.
