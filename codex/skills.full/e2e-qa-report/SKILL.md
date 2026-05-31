---
name: e2e-qa-report
description: E2E QA 리포트를 생성합니다. Playwright로 기능의 전체 워크플로우를 실행하면서 각 단계별 스크린샷을 캡처하고, QA 담당자가 재현 가능한 마크다운 리포트를 출력합니다.
---

# /e2e-qa-report — E2E QA 리포트 생성

## Codex migration guardrails

- Treat this skill as a shared Claude Code ↔ Codex workflow. If source text mentions `.claude/`, Claude-only slash commands, or Claude-only tools, map them to the nearest project docs, `AGENTS.md`, `.codex/`, `.omc/`, native CLI, or available Codex skill/plugin surface.
- Prefer native CLI first for GitHub/Git work (`gh`, `git`) and do not publish issues, PRs, commits, Slack messages, or external side effects without explicit user intent/approval in the current task.
- Flag machine-specific absolute paths, usernames, local archives, and environment-specific assumptions as portability risks.
- Verify with concrete commands or generated evidence before claiming completion.


당신은 프로젝트의 **QA 자동화 엔지니어**입니다.
사용자가 지정한 기능에 대해 Playwright E2E 테스트를 실행하면서 각 단계별 스크린샷을 캡처하고,
QA 담당자가 수동 재현할 수 있는 형태의 **마크다운 QA 리포트**를 생성합니다.

## 사용 예시

```
/e2e-qa-report 리포트 관리 기능
/e2e-qa-report 도서 등록 플로우
/e2e-qa-report 대여/반납 프로세스
```

## 실행 절차

### Phase 1: 대상 기능 파악

1. 사용자가 지정한 기능의 **E2E 테스트 파일**을 찾는다
   - `e2e/*.spec.ts` 에서 관련 파일 탐색
   - 없으면 사용자에게 어떤 플로우를 테스트할지 확인

2. 해당 기능의 **코드와 기획**을 파악한다
   - 관련 page.tsx, 컴포넌트, API route 확인
   - 관련 기획 문서가 있으면 확인

3. **테스트 시나리오 목록**을 도출한다
   - E2E 파일의 `test()` 블록에서 시나리오 추출
   - 또는 기능 플로우에서 핵심 단계 도출

### Phase 2: 스크린샷 캡처용 Playwright 스크립트 작성

기존 E2E 테스트를 기반으로, **각 단계마다 전체 화면 스크린샷을 캡처**하는 전용 스크립트를 작성한다.

**파일 위치**: `e2e/qa-report-{기능명}.spec.ts`

**스크립트 규칙**:

```typescript
import { test, expect } from '@playwright/test';
import path from 'path';

// 스크린샷 저장 경로
const SCREENSHOT_DIR = path.join(__dirname, '../.qa-reports/{기능명}/screenshots');

test.describe.serial('QA Report: {기능명}', () => {
  // 각 단계에서 fullPage 스크린샷 캡처
  async function capture(page: Page, stepName: string) {
    await page.screenshot({
      path: path.join(SCREENSHOT_DIR, `${stepName}.png`),
      fullPage: true,  // 전체 페이지 (스크롤 포함)
    });
  }

  test('Step 01: {단계 설명}', async ({ page }) => {
    await page.goto('/path');
    await page.waitForLoadState('networkidle');
    await capture(page, '01-{단계명}');

    // 검증
    await expect(page.locator('...')).toBeVisible();
  });

  // Dialog/Modal이 있으면 열린 상태에서도 캡처
  test('Step 02: {Dialog 단계}', async ({ page }) => {
    // ... 액션
    await capture(page, '02-{단계명}-dialog-open');

    // Dialog 내 액션 후
    await capture(page, '02-{단계명}-dialog-filled');
  });
});
```

**스크린샷 캡처 원칙**:
- `fullPage: true` — 스크롤 아래 내용도 포함
- Dialog/Modal이 열린 상태에서 반드시 캡처
- 상태 변화 전후 모두 캡처 (예: 생성 전/후, 삭제 전/후)
- 에러 상태도 캡처 (실패 시나리오가 있으면)
- 파일명: `{순번}-{단계명}.png` (예: `01-page-load.png`, `03-dialog-step2-period.png`)

### Phase 3: 스크립트 실행

```bash
# 스크린샷 디렉토리 초기화
rm -rf .qa-reports/{기능명}/screenshots
mkdir -p .qa-reports/{기능명}/screenshots

# Playwright 실행 (headless, 단일 워커)
npx playwright test e2e/qa-report-{기능명}.spec.ts --reporter=line --workers=1
```

실패 시:
- 에러 원인 분석 → 코드 수정 또는 테스트 조정
- 재실행 (최대 3회 이터레이션)

### Phase 4: QA 리포트 마크다운 생성

스크린샷 캡처가 완료되면, 아래 형식의 마크다운 파일을 생성한다.

**파일 위치**: `.qa-reports/{기능명}/report.md`

## QA 리포트 형식

```markdown
# {기능명} — E2E QA 리포트

> 생성일: {날짜}
> 테스트 환경: {URL} / {브라우저}
> 테스트 결과: {통과 N / 실패 N}

---

## 1. 워크플로우 개요

### 기능 설명
{이 기능이 무엇인지, 사용자에게 어떤 가치를 제공하는지}

### 사용자 행동 전환
{이 워크플로우가 유도하는 사용자 행동 변화}
- 전: {기존 사용자 행동}
- 후: {기능 도입 후 기대 행동}

### 서비스 가치
{비즈니스/교육적 가치}

### 고유 리스크
{이 기능 특유의 리스크 — 데이터 정합성, 외부 API 의존, 성능 등}

---

## 2. 테스트 절차 및 결과

### Step 1: {단계명}

**절차**:
1. {수동 재현 단계 1}
2. {수동 재현 단계 2}
3. ...

**확인 체크리스트**:
- [ ] {확인 항목 1}
- [ ] {확인 항목 2}

**결과**: ✅ 통과 / ❌ 실패

**스크린샷**:
![Step 1](./screenshots/01-{단계명}.png)

---

### Step 2: {단계명}

**절차**:
1. ...

**확인 체크리스트**:
- [ ] ...

**결과**: ✅ 통과

**스크린샷**:
![Step 2-a](./screenshots/02-{단계명}-before.png)
![Step 2-b](./screenshots/02-{단계명}-after.png)

---

(... 모든 단계 반복 ...)

## 3. 종합 결과

| # | 단계 | 결과 | 비고 |
|---|------|------|------|
| 1 | {단계명} | ✅ | |
| 2 | {단계명} | ✅ | |
| ... | ... | ... | ... |

### 발견된 이슈
- {이슈 1: 설명 + 심각도}
- {이슈 2: 설명 + 심각도}
- (없으면 "발견된 이슈 없음")

### 개선 제안
- {제안 1}
- {제안 2}
```

## 출력 파일 구조

```
.qa-reports/
└── {기능명}/
    ├── report.md            # QA 리포트 마크다운
    ├── screenshots/
    │   ├── 01-page-load.png
    │   ├── 02-create-dialog-open.png
    │   ├── 02-create-dialog-step1.png
    │   ├── 03-create-dialog-step2.png
    │   ├── 04-create-dialog-step3.png
    │   ├── 05-list-generating.png
    │   ├── 06-list-completed.png
    │   ├── 07-detail-view.png
    │   ├── 08-pdf-print.png
    │   └── ...
    └── qa-report-{기능명}.spec.ts  # (선택) 캡처용 스크립트 사본
```

## 핵심 원칙

1. **QA 담당자가 재현 가능** — 각 단계를 수동으로 따라할 수 있도록 구체적 절차 기술
2. **스크린샷은 전체 화면** — `fullPage: true` + Dialog/Modal 포함
3. **체크리스트는 검증 가능** — "~이 보인다", "~가 동작한다" 형태의 관찰 가능한 항목
4. **워크플로우 맥락 포함** — 왜 이 기능이 존재하는지, 서비스 관점의 가치와 리스크
5. **dev 서버 기반** — `http://localhost:3000`에서 실행, `reuseExistingServer: true`

## 주의사항

- E2E 테스트가 없는 기능이면 먼저 기본 Playwright 스크립트를 작성
- 스크린샷 캡처 실패 시 해당 단계를 "수동 확인 필요"로 표시
- 민감한 개인정보(실제 학생 이름 등)가 스크린샷에 포함될 수 있으므로 리포트 공유 시 주의
- `.qa-reports/` 디렉토리는 `.gitignore`에 추가 권장 (스크린샷 용량)
