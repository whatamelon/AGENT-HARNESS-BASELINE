---
name: admin-build
description: One-shot production-ready admin builder using Neutral Admin Design System v1.0 SSOT (Codex variant). ralplan → goal/team → 4-layer verifier loop. Use for /admin-build, "어드민 만들어", "back-office scaffold", ERP/commerce/finance/CRM/marketing admin from scratch. SSOT at ~/.codex/admin-design/. Security gate at ~/.codex/admin-security/. External orchestrator at ~/.config/agent-harness-baseline/admin-build/bin/admin-build.
x-admin-build:
  ssot_root: "~/.codex/admin-design"
  security_root: "~/.codex/admin-security"
  orchestrator: "~/.config/agent-harness-baseline/admin-build/bin/admin-build"
  agents_md_size_limit_bytes: 32768
  required_context:
    - admin-design/manifest.json
    - admin-design/index.md
    - admin-design/00-non-negotiable.md
    - admin-design/02-ssot-protocol.md
  required_verifiers:
    - admin-design-verifier
    - playwright-smoke
    - rbac-runtime-check
    - axe + screenshot-matrix
  max_iterations: 12
  runtime_budget_hours: 12
  worker_lanes: [shell, table, form, modal, rbac, verifier]
---

# /admin-build (Codex) — One-shot 어드민 builder

## 진입 시 즉시

1. `~/.codex/admin-design/manifest.json` 읽기 — task → section 매핑.
2. `~/.codex/admin-design/index.md`, `00-non-negotiable.md`, `02-ssot-protocol.md` 읽기.
3. `~/.codex/AGENTS.override.md` 의 Admin 라우터 룰 적용.
4. intake yaml 처리.
5. `admin-build attest --task <kind> --agent codex` 실행 → ssot_attestation.json.
6. attestation 없으면 PreToolUse hook 이 apply_patch 차단.

## Phase 흐름 (Claude 와 동일)

```
00-intake → 01-research → 02-plan → 03-verdict → 04-execute → 05-verify → 06-finalize
```

각 phase 의 본문은 Claude/Codex 공통 (`phases/0x-*.md`). Codex 는 `apply_patch` tool 이 주 편집 경로.

## intake.yaml

Claude variant 와 동일 schema. `~/.claude/skills/admin-build/SKILL.md` 본문 참조.

## Tier 0 위반 거부

Codex 의 `--ask-on-write` / `acceptEdits` 모드에서도 동일하게 거부. `permission_mode==bypassPermissions` 일 때만 hook 가 우회 허용 (로그 기록).

## List-page 비협상 3종 (§09-tables §12.9~12.11, 2026-05-29)

table lane worker 에 무조건 명시. `admin-build verify` 가 probe(`pk-column-sole-detail-entry`/`sticky-table-header`/`status-filter-colored`/`pk-cell-helper-present`)로 강제.

1. **PK 단일 진입.** 1번 데이터 컬럼 = PK(`id`) `#`+bold+underline (`pkColumn()`/`PkLink`). 상세 이동은 PK 클릭만. 이름/제목/번호판 등 비-PK 셀은 평문(`<Link>` 금지). 구 `primary_identifier_links_to_detail` 폐기.
2. **Sticky 헤더.** `thead` = `sticky top-0 z-10` + opaque bg. 래퍼 `overflow-hidden` 금지.
3. **상태 필터 의미색.** `FilterChip` tone 지원 + `paramName==='status'` 자동 `toneFor()` 색칠. 흑백 토글만 금지.

## Worker lane (mixed CLI)

`OMX_TEAM_WORKER_CLI_MAP=codex,claude,claude,codex,...` 등으로 mixed 가 기본 (글로벌 룰 `tmux-agents.md`).

## 검증

```bash
admin-build verify
```

PASS 까지 외부 orchestrator 가 loop. Codex 의 Stop hook 도 보조로 `VERIFIER_FAIL` marker 감지 시 continue.

## 32KiB 한도

본 skill 의 SKILL.md + AGENTS.override.md + admin-design/index.md 만 항상 로드. 19 본문 sections 은 manifest.task_router 매핑된 것만 lazy read. AGENTS.md 본문 inline 절대 금지.
