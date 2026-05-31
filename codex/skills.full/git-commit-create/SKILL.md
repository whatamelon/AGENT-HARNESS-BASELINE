---
name: git-commit-create
description: 변경사항을 분석하고 컨벤션에 맞는 Git 커밋을 생성한다.
---

# /git-commit-create — 커밋 생성

## Codex migration guardrails

- Treat this skill as a shared Claude Code ↔ Codex workflow. If source text mentions `.claude/`, Claude-only slash commands, or Claude-only tools, map them to the nearest project docs, `AGENTS.md`, `.codex/`, `.omc/`, native CLI, or available Codex skill/plugin surface.
- Prefer native CLI first for GitHub/Git work (`gh`, `git`) and do not publish issues, PRs, commits, Slack messages, or external side effects without explicit user intent/approval in the current task.
- Flag machine-specific absolute paths, usernames, local archives, and environment-specific assumptions as portability risks.
- Verify with concrete commands or generated evidence before claiming completion.


## 절차

### 1. 브랜치 확인

```bash
git branch --show-current
```

- `main`, `develop` 등 보호 브랜치에 있으면 사용자에게 새 브랜치 생성 여부를 질문한다.

### 2. 변경 사항 확인

```bash
git status
git diff
git diff --staged
```

### 3. 기존 커밋 스타일 확인

```bash
git log --oneline -10
```

### 4. 커밋 메시지 작성

**형식:**
```
<type>(<scope>): <subject>

<body>
```

**타입:** feat, fix, refactor, style, docs, test, chore, build, ci, perf

### 5. 사용자 확인 후 실행

커밋 메시지를 사용자에게 보여주고, 승인을 받은 후 실행한다.

```bash
git add <파일 목록>
git commit -m "$(cat <<'EOF'
<type>(<scope>): <subject>

<body>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

**주의:**
- 사용자 승인 전에 `git commit` 실행 금지
- `.env`, 시크릿 파일은 커밋에 포함하지 않는다
- `git add -A` 대신 구체적 파일명을 지정한다
