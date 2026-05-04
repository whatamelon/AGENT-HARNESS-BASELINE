---
name: git-pr-create
description: 현재 브랜치의 변경사항을 분석하고 GitHub PR을 생성한다.
---

# /git-pr-create — GitHub PR 생성

## Codex migration guardrails

- Treat this skill as a shared Claude Code ↔ Codex workflow. If source text mentions `.claude/`, Claude-only slash commands, or Claude-only tools, map them to the nearest project docs, `AGENTS.md`, `.codex/`, `.omc/`, native CLI, or available Codex skill/plugin surface.
- Prefer native CLI first for GitHub/Git work (`gh`, `git`) and do not publish issues, PRs, commits, Slack messages, or external side effects without explicit user intent/approval in the current task.
- Flag machine-specific absolute paths, usernames, local archives, and environment-specific assumptions as portability risks.
- Verify with concrete commands or generated evidence before claiming completion.


## 절차

### 1. 변경사항 분석

```bash
git branch --show-current
git status
git log --oneline main..HEAD
git diff main...HEAD --stat
```

### 2. 정보 확인

사용자에게 다음을 확인한다:
- **base 브랜치**: 기본 `main` (다른 경우 질문)
- **관련 이슈 번호**: `#이슈번호` 형식

### 3. PR 미리보기

변경 내용을 분석하여 PR 제목과 본문을 작성하고 사용자에게 보여준다.

### 4. 사용자 확인 후 생성

```bash
git push -u origin HEAD
```

```bash
gh pr create \
  --title "<PR 제목>" \
  --body "$(cat <<'EOF'
## Summary
<변경 내용 요약 (1-3줄)>

## Changes
- <변경 파일/기능별 설명>

## Related Issues
- closes #<이슈번호>

## Test Plan
- [ ] `npm run build` 통과
- [ ] `npm run lint:fix` 에러 없음
- [ ] <기능별 테스트 항목>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

생성 완료 후 PR URL을 사용자에게 전달한다.

**주의:**
- 사용자 승인 전에 `git push` 실행 금지
- PR 본문에 변경 목적과 테스트 방법을 반드시 포함
