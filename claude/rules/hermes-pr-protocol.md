# Hermes PR 프로토콜 — whatamelon 계정 PR 작성 강제 규칙

## 핵심 규칙

> **whatamelon 계정으로 GitHub/GitLab PR을 올릴 때, 반드시 아래 전체 프로토콜을 따른다. Hermes 자동 코드리뷰/QA 에이전트가 후속 검증할 수 있도록 PR에 "검증 맥락"을 남기는 것이 목적이다.**

## 목표

- Hermes가 PR diff만 보고 추측하지 않게 만든다.
- 어떤 사용자 flow를 QA해야 하는지 명확히 알려준다.
- 어떤 것은 QA하지 않아도 되는지 명확히 제외한다.
- UI/기능 baseline이 무엇인지 남긴다.
- 다른 merge agent가 Hermes의 review/QA handoff 코멘트를 보고 안전하게 main에 머지할 수 있게 한다.

---

## 1. PR body 필수 섹션

PR body에 반드시 아래 섹션을 **전부** 포함한다.

```markdown
## Summary
- 변경 목적:
- 주요 변경 파일/영역:
- 사용자에게 보이는 변화:
- 내부 리팩터링/비가시 변화:

## Risk Profile
- Risk level: low | medium | high
- Risk 이유:
- 영향 범위:
- rollback 방법:

## QA Context for Hermes

### QA 해야 하는 것
- [ ] Flow 1:
  - 시작 URL:
  - 테스트 계정/권한:
  - 입력값:
  - 기대 결과:
- [ ] Flow 2:
  - 시작 URL:
  - 테스트 계정/권한:
  - 입력값:
  - 기대 결과:
- [ ] Console/runtime error 확인 필요: yes | no
- [ ] Mobile/responsive 확인 필요: yes | no
- [ ] Empty/error/loading state 확인 필요: yes | no

### QA 하지 않아도 되는 것
- 제외 flow:
- 제외 이유:
- 이번 PR에서 영향 없는 영역:

## Baseline / Expected Behavior
- 변경 전 정상 동작:
- 변경 후 기대 동작:
- 유지되어야 하는 invariant:
- 절대 깨지면 안 되는 것:
- 관련 screenshot/storybook/design/spec 링크:

## Preview / Environment
- Preview URL:
- Staging URL:
- Local run command:
- Required env/feature flag:
- Seed/test data:
- Known flaky/irrelevant checks:

## Test Plan
- [ ] unit:
- [ ] typecheck:
- [ ] lint:
- [ ] build:
- [ ] e2e/manual:
- [ ] 직접 확인한 브라우저/환경:

## Merge Guidance
- 자동머지 허용 여부: no | only if automerge:l3 label is present
- 사람이 반드시 봐야 하는 조건:
- Hermes/다른 에이전트가 merge 전에 재검증해야 할 조건:
```

---

## 2. PR 라벨 규칙

**기본:** 라벨 없음 → Hermes가 코드리뷰/QA 코멘트만 남기고 자동머지하지 않는다.

| 라벨 | 의미 | 사용 조건 |
|------|------|-----------|
| `automerge:l3` | CI/QA 통과 시 자동머지 후보 | 정말 low-risk이고 확신할 때만. 확신 없으면 붙이지 마라 |
| `qa:required` | UI/flow 검증 반드시 필요 | 사용자 화면 변경 PR |
| `qa:skip` | QA 불필요 | PR body에 이유 필수 |
| `manual-review` | 자동머지 금지, 사람/상위 에이전트 필수 | 위험 변경 |
| `hold` | 어떤 자동화도 merge 금지 | 보류 상태 |
| `needs-security` | 보안 관점 리뷰 필요 | auth/secret/permission 변경 |
| `needs-legal` | 법무/정책 검토 필요 | 약관/개인정보/라이선스 변경 |

---

## 3. QA 필요 여부 판단 기준

### 반드시 QA해야 하는 PR

- 사용자 화면 변경
- route/page/component/form 변경
- auth/login/session/permission 변경
- billing/payment/plan/upgrade 변경
- admin/운영툴 변경
- onboarding/signup/invite flow 변경
- data mutation flow 변경
- API response shape가 UI에 영향 주는 변경
- loading/error/empty state 변경
- CSS/layout/design system 변경
- mobile/responsive 영향 가능성
- copy 변경이 conversion/법적 문구/가격/권한에 영향 주는 경우

### QA 생략 가능한 PR

- README/docs-only
- comment-only
- test-only (production code 영향 없음)
- internal type cleanup (runtime behavior 변화 없음이 명확)
- dead code removal (실제 import/use 없음이 검증된 경우)
- build config 변경이지만 user flow와 무관하고 CI가 충분히 커버하는 경우

### 주의

- "작은 변경"은 QA skip 이유가 아니다.
- "타입만 바꿨다"도 API boundary, form schema, DB type, generated client면 QA 대상일 수 있다.
- auth/payment/admin/migration/infra/security는 원칙적으로 QA 또는 manual review 대상이다.

---

## 4. Baseline 작성 규칙

Hermes가 "무엇이 정상인지" 알 수 있게 baseline을 남긴다.

**좋은 baseline:**

```
- /admin/vehicles 에서 차량 목록이 2초 내 표시되어야 한다.
- 필터를 변경하면 URL query가 갱신되고 목록이 재조회된다.
- 빈 결과면 "검색 결과가 없습니다" empty state가 표시된다.
- 저장 성공 시 toast가 뜨고 modal이 닫힌다.
- 권한 없는 사용자는 /login으로 redirect된다.
```

**나쁜 baseline (금지):**

```
잘 동작해야 함
기존과 동일
문제 없어야 함
```

**Baseline 최소 포함 사항:**
- 시작 URL
- 정상 완료 조건
- 오류/empty/loading 상태
- 권한/role 차이
- 저장/수정/삭제 후 기대 상태
- 유지되어야 하는 copy/format/currency/date/locale
- 기존 screenshot/storybook/design 링크

---

## 5. Preview URL 규칙

PR body에 preview URL 반드시 포함.

**우선순위:** Vercel/Netlify/Cloudflare preview → staging URL → local run command → QA 불가 사유

Preview URL이 없으면:

```
- Preview URL: unavailable
- Reason:
- Local run command:
- Required env:
```

---

## 6. 테스트 계정/시크릿 규칙

**절대** PR body나 코멘트에 비밀번호/API key/token을 쓰지 않는다.

```
- Test account: standard QA user from shared secret store
- Required role: admin
- Secret source: existing CI/Hermes env only
```

---

## 7. Merge agent handoff 규칙

Hermes가 PR에 남기는 마커/상태를 읽어라:

- `<!-- hermes-review:... -->`
- `<!-- hermes-merge-handoff:... -->`
- `Status: merge_candidate_after_revalidation`
- `Status: do_not_merge_without_human_or_follow-up_agent`

다른 merge agent는 `merge_candidate_after_revalidation`이 있더라도 바로 merge하지 않고 **반드시 재검증**:

```bash
gh pr view <PR_NUMBER> --repo <OWNER/REPO> --json headRefOid,mergeStateStatus,isDraft,labels,reviewDecision,statusCheckRollup
```

확인 항목:
- head SHA == Hermes 코멘트의 reviewed SHA
- PR이 open, draft 아님
- blocking label 없음: `hold`, `manual-review`, `do-not-merge`, `needs-security`, `needs-legal`, `wip`
- checks green
- base branch 의도 일치
- PR 작성자/변경 범위가 정책상 허용

merge 시 반드시 SHA pinning:

```bash
gh pr merge <PR_NUMBER> \
  --repo <OWNER/REPO> \
  --squash \
  --delete-branch \
  --match-head-commit <REVIEWED_HEAD_SHA>
```

`--auto` 사용 금지. stale review 기반 future merge 위험.

---

## 8. PR 크기 제한

| 권장 | 값 |
|------|-----|
| changed files | ≤ 10 |
| additions | ≤ 300 |
| deletions | ≤ 300 |
| 목적 | 하나의 user-visible 목적 |

초과 시: PR body에 이유 설명 + QA 범위 우선순위 명시 + `manual-review` 기본.

---

## 9. 위험 변경 automerge 금지

아래 변경이 포함되면 `automerge:l3` 붙이지 않는다:

- `.github/workflows/**`
- infra/terraform/k8s/deployment
- DB migration
- auth/session/security/permission
- billing/payment
- secrets/env/config
- package publishing/release
- destructive data operation
- user role/tenant isolation
- production traffic routing

필요하면 `manual-review`, `needs-security`, `hold` 사용.

---

## 10. PR body 예시

```markdown
## Summary
- 변경 목적: 차량 점검지 상세 route에서 Supabase client any-cast 제거
- 주요 변경 파일/영역: app/api/vehicle_checkpaper/[id]/route.ts
- 사용자에게 보이는 변화: 없음
- 내부 리팩터링/비가시 변화: 타입 안정성 개선

## Risk Profile
- Risk level: low
- Risk 이유: query shape/runtime logic 변경 없음, 타입 캐스팅만 제거
- 영향 범위: vehicle_checkpaper 상세 조회 API
- rollback 방법: 이전 cast 복구

## QA Context for Hermes

### QA 해야 하는 것
- [ ] Flow 1: 차량 점검지 상세 조회
  - 시작 URL: Preview URL + /admin/vehicles/{id}/checkpaper
  - 테스트 계정/권한: admin QA user
  - 입력값: 기존 seed 차량
  - 기대 결과: 점검지 상세가 기존과 동일하게 표시됨
- [ ] Console/runtime error 확인 필요: yes
- [ ] Mobile/responsive 확인 필요: no
- [ ] Empty/error/loading state 확인 필요: yes

### QA 하지 않아도 되는 것
- 차량 생성/삭제 flow
- 결제/권한/로그인 flow
- 이유: 이번 PR은 점검지 조회 route typing에만 영향

## Baseline / Expected Behavior
- 기존 admin 차량 상세에서 점검지 섹션이 정상 표시되어야 함
- 점검지 데이터가 없으면 empty state가 표시되어야 함
- API 500/console error가 없어야 함
- 기존 UI layout/copy는 바뀌면 안 됨

## Preview / Environment
- Preview URL: https://...
- Required env/feature flag: existing preview env
- Seed/test data: existing QA vehicle

## Test Plan
- [ ] typecheck: passed
- [ ] lint: passed
- [ ] build: passed
- [ ] manual preview check: pending Hermes QA

## Merge Guidance
- 자동머지 허용 여부: only if automerge:l3 label is present
- 사람이 반드시 봐야 하는 조건: API 500, 점검지 누락, 권한 redirect 이상
- Hermes/다른 에이전트가 merge 전에 재검증해야 할 조건: head SHA unchanged, checks green, QA pass
```

---

## How to apply

- whatamelon 계정으로 `gh pr create` 또는 GitLab MR 생성 시 위 템플릿 전체를 PR body에 채워 넣는다
- 섹션을 빼거나 "해당 없음"으로 뭉뚱그리지 않는다 — 해당 없는 항목은 구체적 이유와 함께 기재
- PR 생성 전에 QA 판단 기준(§3)을 먼저 체크해 적절한 라벨을 결정한다
- 기존 `git-workflow.md` 규칙(브랜치 전략, 커밋 메시지, force push 금지 등)과 함께 적용
- 이 룰은 whatamelon 계정의 PR에만 적용. 다른 계정/봇이 올리는 PR에는 강제하지 않음

## Why

**Why:** Hermes 자동 코드리뷰/QA 에이전트가 PR diff만으로 추측하지 않고 정확한 검증을 수행하려면, PR 작성 시점에 충분한 검증 맥락이 있어야 한다. 또한 다른 merge agent가 Hermes handoff 코멘트를 보고 안전하게 main에 머지할 수 있어야 한다. 사용자가 전역 강제를 명시 지시(2026-05-26).

**How to judge edge cases:** "Hermes가 이 PR을 받았을 때, diff 외에 추가 질문 없이 QA를 완료할 수 있는가?" 할 수 없으면 정보가 부족한 것이다. Baseline이 모호하거나 QA flow가 빠져 있으면 PR body를 보충한다.
