# Admin Design System — Shared SSOT 강제 참조

## Canonical source

- `~/.config/agent-harness-baseline/admin-design/` — Neutral Admin Design System v1.0 (19 sections + manifest + machine specs)
- `~/.config/agent-harness-baseline/admin-security/` — RBAC matrix, RLS tests, audit-log contract, secret-leak — UI verifier 와 **동급 게이트**

심볼릭:

- `~/.claude/admin-design`, `~/.claude/admin-security`
- `~/.codex/admin-design`, `~/.codex/admin-security`

repo-local 추가 (Tier 2 추가/구체화만):

- `<repo>/admin/admin-design/local.md` ← `_local-template.md` 복사 후 채움

## 트리거 키워드

다음 키워드가 user prompt 또는 task description 에 보이면 본 SSOT 강제 참조:

```
어드민 | admin | 관리자 | back-office | 백오피스 | 대시보드 | dashboard | 운영툴
ERP | CRM | 어드민 페이지 | 어드민 만들어 | 어드민 구축
admin-build | /admin-build | 어드민 1샷 | one-shot admin
```

## Rule

UI/UX/product/visual/RBAC/state taxonomy/data table/form/modal/dashboard 작업 시작 시 다음 순서:

1. **`~/.claude/admin-design/manifest.json` 로드** — task → section 매핑.
2. **`~/.claude/admin-design/index.md` 로드** — 항상.
3. **`00-non-negotiable.md` + `02-ssot-protocol.md` 로드** — 항상.
4. **`manifest.json::task_router` 가 가리키는 섹션만 추가 로드** — 전체 19 파일 통째로 로드 금지.
5. **첫 어드민 코드 수정/생성 전** `.admin-build/runs/<ts>/ssot_attestation.json` 생성:
   ```json
   {
     "ssot_version": "admin-design@1.0.0",
     "manifest_hash": "<sha256 of manifest.json>",
     "loaded_sections": [{"file": "...", "sha256": "..."}, ...],
     "task_to_section_map": {"<file_or_route>": ["<section1>", ...]},
     "local_override_applied": "admin/admin-design/local.md@sha256:<hash>" or null,
     "exceptions": [],
     "worker_id": "<lane or 'main'>",
     "agent_cli": "claude-opus-4-7"
   }
   ```
6. **작업 종료 전** `admin-build verify` 실행 — 4-layer verifier 통과 못 하면 미완료로 간주, 수정 회귀.

## Override precedence

| Tier | Scope | override |
|---|---|---|
| 0 | `00-non-negotiable.md` | **forbidden** |
| 1 | `01-18` global 본문 | 추가/구체화만 via Tier 2 |
| 2 | repo `admin/admin-design/local.md` | additive only — 완화 불가 |
| 3 | task prompt (intake) | domain/business/db/permission only |

Tier 0 위반 시도 (예: "이번 PR 만 dark mode 켜", "이번엔 mock data 살려") → 즉시 reject + 사용자에게 사유 명시.

## 다른 디자인 룰과의 관계

- `[[no-design-slop]]` (글로벌) — 본 룰과 호환. 어드민도 동일 anti-slop.
- `[[no-decorative-eyebrow]]` — 본 SSOT §0/§3 와 정합.
- `[[ui-service-quality-bar]]` — 모바일 B2C 기준. 어드민에는 본 SSOT 우선.
- `[[light-mode-enforcement-three-layers]]` — 본 SSOT §0 Tier 0 와 동일 강제.
- `[[react-native-web]]` — 본 SSOT 는 web 어드민 (RN 외). RN 어드민 작업 시 두 룰 함께.

## 진입 시 자동 announce

본 룰을 따르는 세션에서는 응답 첫 줄에 다음 announce 권장:

> "Neutral Admin Design System v1.0 SSOT 로드. Tier 0 lock 활성. (manifest hash: <첫 12자>)"

## Sync

`~/.config/agent-harness-baseline/admin-design/` 가 정본. 머신 로컬 분기 사본 생성 금지. 갱신 시 본 디렉토리 수정 + `bash ~/.config/agent-harness-baseline/bin/sync-attest.sh` (있을 경우) 실행.

## Why

**Why:** 어드민 one-shot 구축 시 LLM 이 디자인 일관성 없이 generic SaaS 톤으로 흘러가는 문제 (사용자 2026-05-27 지시). v2 하네스는 attestation + 4-layer verifier 로 강제. 본 룰은 자동 로드 진입점.

**How to apply:** 어드민 키워드 감지 → manifest 로드 → 필요한 섹션만 read → attestation 생성 → 작업 → verifier 통과 → 완료. attestation 없으면 PreToolUse hook 이 어드민 route Edit/Write deny.
