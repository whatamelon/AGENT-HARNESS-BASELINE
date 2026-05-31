---
name: git-extract-pr
description: dirty 워킹트리에서 특정 파일만 추출하여 별도 브랜치 PR을 생성한다. 로컬 변경사항에 영향 없이 worktree 격리 방식으로 안전하게 부분 머지한다. "이것만 따로 PR", "이 파일만 머지", "로컬 건드리지 말고 PR", "부분 PR", "선택적 PR", "나머지는 놔두고 이것만", "develop에 이것만 반영", "extract PR", "worktree로 PR" 등의 요청에 사용한다.
argument-hint: "<PR에 포함할 파일 또는 작업 설명>"
---

# /git-extract-pr — dirty 워킹트리에서 파일 추출 PR

## Codex migration guardrails

- Treat this skill as a shared Claude Code ↔ Codex workflow. If source text mentions `.claude/`, Claude-only slash commands, or Claude-only tools, map them to the nearest project docs, `AGENTS.md`, `.codex/`, `.omc/`, native CLI, or available Codex skill/plugin surface.
- Prefer native CLI first for GitHub/Git work (`gh`, `git`) and do not publish issues, PRs, commits, Slack messages, or external side effects without explicit user intent/approval in the current task.
- Flag machine-specific absolute paths, usernames, local archives, and environment-specific assumptions as portability risks.
- Verify with concrete commands or generated evidence before claiming completion.


develop에서 여러 작업을 동시에 진행 중일 때, **특정 파일만 분리해서 별도 브랜치 PR로 머지**하고 나머지 로컬 변경은 그대로 유지한다.

핵심: `git worktree`로 별도 작업 공간을 만들어 현재 디렉토리를 **절대 건드리지 않는다**.

사용자 요청: **$ARGUMENTS**

---

## Step 1. 현황 파악

```bash
git status -s
```

dirty 파일 목록을 표시하고, `$ARGUMENTS` 또는 대화 컨텍스트에서 **PR에 포함할 대상 파일**을 특정한다.

파일 상태별 분류:
- `??` — 신규 파일 (untracked)
- ` M` / `M ` — 수정 파일 (modified)
- ` D` — 삭제 파일 (deleted)

---

## Step 2. 계획 수립 → 사용자 확인

아래 정보를 제시하고 **사용자 승인을 받는다**:

```
대상 파일:
  - path/to/file1.md (신규)
  - path/to/file2.ts (수정)

브랜치명: docs/chg-040-xxx (또는 feat/xxx, fix/xxx)
베이스: develop
커밋 메시지: "docs: CHG-040 레거시 ERP 인프라 요청서"
```

사용자가 수정 요청하면 반영. 승인 후 다음 단계 진행.

---

## Step 3. worktree 생성

```bash
git worktree add ../{현재폴더명}-extract -b {브랜치명} {base_branch}
```

- `{현재폴더명}`: `basename $PWD` (예: `som-erp` → `../som-erp-extract`)
- `{base_branch}`: 기본값 `develop`, 사용자 지정 가능
- 이 명령은 현재 디렉토리에 **아무 영향 없음**

---

## Step 4. 파일 적용

대상 파일을 worktree에 복사한다. **메인 worktree의 파일은 건드리지 않는다.**

```bash
# 신규 파일 (??)
mkdir -p ../{현재폴더명}-extract/{디렉토리} 
cp {파일경로} ../{현재폴더명}-extract/{파일경로}

# 수정 파일 (M) — 현재 dirty 상태 그대로 복사
cp {파일경로} ../{현재폴더명}-extract/{파일경로}

# 삭제 파일 (D)
cd ../{현재폴더명}-extract && git rm {파일경로}
```

---

## Step 5. 커밋 + PR 생성

worktree 디렉토리에서 실행:

```bash
cd ../{현재폴더명}-extract

# 스테이징
git add {파일1} {파일2} ...

# 커밋
git commit -m "$(cat <<'EOF'
{커밋 메시지}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"

# 푸시
git push -u origin {브랜치명}

# PR 생성
gh pr create --base {base_branch} --title "{PR 제목}" --body "$(cat <<'EOF'
## Summary
- {변경 요약}

## Test plan
- [x] 대상 파일만 포함 확인
- [x] 로컬 변경사항 보존 확인

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

PR URL을 사용자에게 제시한다.

---

## Step 6. (선택) 즉시 머지 → 사용자 확인

사용자에게 즉시 머지할지 묻는다. 승인 시:

```bash
# ⚠ --delete-branch 사용 금지 (worktree가 브랜치를 점유 중이라 실패함)
# ⚠ 반드시 메인 worktree에서 실행 (worktree에서 하면 에러)
cd {메인_worktree_경로}
gh pr merge {PR번호} --squash
```

**주의 2가지:**
1. `--delete-branch` 붙이면 worktree가 점유 중인 로컬 브랜치를 지우려다 실패한다. **브랜치 삭제는 Step 7에서 worktree 제거 후 수행.**
2. worktree 디렉토리에서 `gh pr merge`를 실행하면 `fatal: 'develop' is already used by worktree` 에러가 발생한다. **반드시 메인 worktree로 돌아와서 실행.**

---

## Step 7. 정리 + 복원

**순서가 중요하다** — worktree 제거 → 브랜치 삭제 → 중복 해소 → pull.

```bash
# 1) worktree 제거 (이게 먼저 — 브랜치 점유 해제)
git worktree remove ../{현재폴더명}-extract

# 2) 로컬 브랜치 정리 (worktree 제거 후에야 삭제 가능)
git branch -d {브랜치명}

# 3) 로컬 중복 파일 해소 (머지된 파일이 로컬에도 있으면 pull 실패)
#    수정 파일 (M) → 원복
git checkout -- {수정파일1} {수정파일2}
#    신규 파일 (??) → 삭제
rm {신규파일1} {신규파일2}

# 4) 머지된 내용 가져오기
git pull origin {base_branch}

# 5) 로컬 변경사항 보존 확인
git status -s
```

최종 `git status`를 표시하여 **추출한 파일 외의 변경사항이 그대로 보존**되었음을 확인한다.

---

## 설계 원칙

- **현재 작업 디렉토리 절대 불변** — `git checkout`, `git stash` 등 현재 트리를 변경하는 명령 금지
- **사용자 확인 2회** — Step 2(계획 승인), Step 6(머지 여부)
- **실패해도 안전** — worktree는 독립 공간이므로 실패해도 원본에 영향 없음
- **정리 필수** — worktree + 로컬 브랜치 + 중복 파일 모두 정리 후 종료

## 트러블슈팅

| 상황 | 원인 | 대응 |
|------|------|------|
| `gh pr merge --delete-branch` 에러: `cannot delete branch used by worktree` | worktree가 브랜치를 점유 중인데 `--delete-branch`로 삭제 시도 | `--delete-branch` 빼고 머지 → worktree 제거 후 `git branch -d` |
| `gh pr merge` 에러: `'develop' is already used by worktree` | worktree 디렉토리에서 실행함 | 메인 worktree로 이동 후 실행 |
| `git pull` 에러: `local changes would be overwritten` | 머지된 파일이 로컬에도 dirty로 존재 | Step 7의 중복 해소 절차 수행 후 pull |
| `git pull` 에러: `untracked working tree files would be overwritten` | 머지된 신규 파일이 로컬에도 untracked로 존재 | `rm` 으로 로컬 사본 삭제 후 pull |
| worktree 생성 실패: `branch already exists` | 동일 브랜치명이 이미 존재 | 브랜치명 변경하거나 기존 브랜치 삭제 |
