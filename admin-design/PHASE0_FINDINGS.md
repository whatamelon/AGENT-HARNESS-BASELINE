---
slug: phase0-findings
role: build-artifact
description: Phase 0 공식 doc 검증 결과 — v2 하네스 설계 결정 근거
created: 2026-05-27
---

# Phase 0 — 공식 doc 검증 결과 (v2 설계 sanity check)

## Claude Code hooks (확정)

Source: `https://code.claude.com/docs/en/hooks`

| Event | 용도 | 결정 제어 |
|---|---|---|
| SessionStart | 세션 진입 시 | additionalContext |
| UserPromptSubmit | user prompt 제출 시 | block / additionalContext |
| **UserPromptExpansion** | **slash command 확장 시 (PreToolUse 우회)** | block / additionalContext |
| PreToolUse | tool 실행 전 | `permissionDecision`: `allow|deny|ask|defer` + `updatedInput` |
| PostToolUse | tool 완료 후 | additionalContext |
| Stop | turn 종료 시 | block (continues conversation) |

**Key finding**:
- `UserPromptExpansion` 공식 존재. `expansion_type` (`slash_command`/`mcp_prompt`), `command_name`, `command_args`, `command_source` payload.
- Stop hook iteration cap 공식 문서 **미명시**. 8회 한도 주장은 검증 불가. → **external orchestrator 패턴 유지** (Stop 만 의존하면 위험).

## Codex CLI hooks (확정)

Source: `https://developers.openai.com/codex/hooks`

지원 lifecycle:
- SessionStart (thread/subagent-start scope)
- UserPromptSubmit
- PreToolUse
- PermissionRequest
- PostToolUse
- PreCompact
- PostCompact
- SubagentStart
- SubagentStop
- Stop

(turn scope: PreToolUse, PermissionRequest, PostToolUse, PreCompact, PostCompact, UserPromptSubmit, SubagentStop, Stop)

`permission_mode` payload 포함: `default | acceptEdits | plan | dontAsk | bypassPermissions`.

**Key finding**:
- Codex hooks 는 **공식 1급 시민**. v1 의 "Codex 는 AGENTS.md 중심" 가정은 폐기.
- 다중 소스 (global + project + nested) 모두 로드 — override 가 아니라 **누적**.

## AGENTS.md size limit (확정)

Source: `https://developers.openai.com/codex/guides/agents-md`

- `project_doc_max_bytes` default **32 KiB** 결합 한도.
- 한도 초과 시 **silent truncate** — 끝부분 instruction 무시.
- Precedence: `AGENTS.override.md` > `AGENTS.md`. 디렉토리 가까울수록 늦게 들어와 우선 (later overrides earlier).

**v2 영향**:
- `~/.codex/AGENTS.md` 본문은 **< 4KiB 목표 thin router**. admin-design 본문 inline 절대 금지.
- `AGENTS.override.md` 활용 가능 — 프로젝트별 admin-design 트리거 룰 보강.

## v2 설계 반영

| 항목 | v2 조치 |
|---|---|
| Claude `UserPromptExpansion` | `/admin-build` slash 명령 잡는 hook 추가 (PreToolUse 우회 차단) |
| Stop hook cap 미확정 | `admin-build` CLI 가 외부 loop 책임. Stop hook 은 보조 only |
| Codex hooks 1급 | Claude 와 대칭 5종 hook 작성 |
| Codex `permission_mode` | hook payload 활용해 plan/bypass mode 차별 처리 |
| 32KiB cap | Codex `AGENTS.md` thin router 강제. lazy load 본문 |
| 다중 소스 누적 | `~/.codex/AGENTS.md` (global router) + repo `AGENTS.md` (project local) 둘 다 의도적 활용 |
