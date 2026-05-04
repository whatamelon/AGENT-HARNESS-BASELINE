---
name: sync-issues
description: GitHub 이슈/PR을 archives 폴더에 동기화한다.
---

# /sync-issues — GitHub 이슈/PR 동기화

## Codex migration guardrails

- Treat this skill as a shared Claude Code ↔ Codex workflow. If source text mentions `.claude/`, Claude-only slash commands, or Claude-only tools, map them to the nearest project docs, `AGENTS.md`, `.codex/`, `.omc/`, native CLI, or available Codex skill/plugin surface.
- Prefer native CLI first for GitHub/Git work (`gh`, `git`) and do not publish issues, PRs, commits, Slack messages, or external side effects without explicit user intent/approval in the current task.
- Flag machine-specific absolute paths, usernames, local archives, and environment-specific assumptions as portability risks.
- Verify with concrete commands or generated evidence before claiming completion.


## 역할

GitHub의 이슈와 PR을 로컬 `archives/` 폴더에 동기화한다.

## 실행

```bash
node scripts/issues/sync.mjs
```

실행 결과를 사용자에게 보여준다.

## 동작 설명

- GitHub API를 통해 이슈와 PR 목록을 조회한다.
- 각 항목별로 `archives/` 하위에 폴더를 생성/갱신한다.
- 폴더명 형식: `#번호_[타입] 제목`
- 기존 폴더가 있으면 제목 변경 시 이름을 갱신한다.

## 사전 조건

- GitHub CLI(`gh`) 설치 및 인증 완료
- 저장소가 GitHub에 연결되어 있어야 함
