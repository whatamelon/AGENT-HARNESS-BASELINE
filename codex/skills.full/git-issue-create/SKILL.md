---
name: git-issue-create
description: 사용자 인터뷰 후 GitHub 이슈를 생성한다.
---

# /git-issue-create — GitHub 이슈 생성

## Codex migration guardrails

- Treat this skill as a shared Claude Code ↔ Codex workflow. If source text mentions `.claude/`, Claude-only slash commands, or Claude-only tools, map them to the nearest project docs, `AGENTS.md`, `.codex/`, `.omc/`, native CLI, or available Codex skill/plugin surface.
- Prefer native CLI first for GitHub/Git work (`gh`, `git`) and do not publish issues, PRs, commits, Slack messages, or external side effects without explicit user intent/approval in the current task.
- Flag machine-specific absolute paths, usernames, local archives, and environment-specific assumptions as portability risks.
- Verify with concrete commands or generated evidence before claiming completion.


## 절차

### 1. 사용자 인터뷰

다음 정보를 수집한다:

| 항목 | 필수 | 설명 |
|------|------|------|
| 이슈 유형 | O | bug, feature, improvement, task 중 선택 |
| 제목 | O | 간결하고 명확한 한 줄 제목 |
| 상세 내용 | O | 배경, 현상(버그), 기대 동작, 구현 범위 등 |
| 라벨 | - | 타입, 우선도, 모듈 등 |
| 담당자 | - | GitHub 사용자명 |
| 마일스톤 | - | 연결할 마일스톤 |

### 2. 이슈 미리보기

수집한 정보로 이슈를 구성하여 사용자에게 보여준다.

### 3. 사용자 확인 후 생성

```bash
gh issue create \
  --title "<제목>" \
  --body "$(cat <<'EOF'
## 개요
<상세 내용>

## 관련 정보
- 모듈: <관련 모듈>
- 우선도: <높음/중간/낮음>

## 작업 항목
- [ ] <체크리스트>
EOF
)" \
  --label "<라벨1>,<라벨2>" \
  --assignee "<담당자>"
```

생성 완료 후 이슈 URL을 사용자에게 전달한다.
