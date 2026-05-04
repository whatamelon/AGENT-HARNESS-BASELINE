---
name: refactor-comply
description: 코드를 프로젝트 규칙에 맞게 리팩토링한다 — 위반 진단 → 회귀 테스트 → 리팩토링 → 검증 → 보고서.
argument-hint: '<대상 파일/디렉토리 경로> [--scope architecture|convention|quality|all] [--gate diagnose|plan|refactor]'
---

사용자가 리팩토링을 요청했습니다: **$ARGUMENTS**

---

## 개요

이 스킬은 기존 코드를 프로젝트 규칙에 맞게 리팩토링하는 전체 사이클을 가이드한다.
리팩토링의 핵심 원칙은 **"동작은 보존하고, 구조만 개선한다"** — 테스트가 이를 보장한다.

```
[0] 컨텍스트 확인  →  [1] 위반 진단  →  [2] 회귀 테스트 작성  →  [3] 리팩토링 계획  →  [4] 리팩토링 실행  →  [5] 테스트 검증  →  [6] 결과 보고서
```

## 외부 스킬 적용

- **프론트엔드 패턴**: vercel-react-best-practices, vercel-composition-patterns
- **타입**: typescript-advanced-types
- **DB**: supabase-postgres-best-practices
- **테스트**: vitest

## 사전 준비 — 조건부 Reference Read

> 리팩토링 범위에 따라 필요한 reference 파일만 Read한다. 이미 현재 세션에서 Read한 파일은 재읽기 불필요.

| 리팩토링 대상 | 필수 Read |
|--------------|-----------|
| 아키텍처 정리 | `.claude/references/architecture.md` |
| 프론트엔드 | + `.claude/references/frontend-guide.md` |
| API 리팩토링 | + `.claude/references/api-design.md` |
| DB 구조 변경 | + `.claude/references/db-schema.md` |
| 테스트 추가 | + `.claude/references/testing-guide.md` |

---

## Step 0. 인자 파싱 및 컨텍스트 확인

### 0-1. 인자 파싱

`$ARGUMENTS`에서 다음을 추출한다:

| 인자       | 기본값 | 설명                                                              |
| ---------- | ------ | ----------------------------------------------------------------- |
| `<대상>`   | (필수) | 리팩토링 대상 파일 또는 디렉토리 경로                             |
| `--scope`  | `all`  | 진단 범위: `architecture`, `convention`, `quality`, `all`         |
| `--gate`   | `refactor` | 어디서 멈출지: `diagnose`, `plan`, `refactor`                 |

### 0-2. 대상 코드 확인

대상 경로의 존재와 범위를 확인한다:

1. 파일이면 해당 파일과 직접 의존하는 파일들을 대상에 포함
2. 디렉토리면 하위 `*.ts`, `*.tsx` 파일 전체를 대상으로 스캔
3. 대상 파일이 20개를 초과하면 사용자에게 범위 축소를 제안

### 0-3. 규칙 파일 로드

대상 코드와 대조할 프로젝트 규칙을 읽는다:

| `--scope` 값     | 로드할 규칙 파일                                              |
| ----------------- | ------------------------------------------------------------- |
| `architecture`    | `.claude/rules/core/architecture-essentials.md`               |
| `convention`      | `.claude/rules/core/architecture-essentials.md` (네이밍 섹션) |
| `quality`         | `.claude/rules/core/architecture-essentials.md` + `business-core-rules.md` + `db-essentials.md`  |
| `all`             | 위 전부 + `.claude/references/testing-guide.md`              |

### 0-4. 출력 폴더 결정

```
.task/.refactoring/YYYY-MM-DD-<kebab-case-대상명>/
├── 01-diagnosis.md      ← Step 1 산출물
├── 02-test-plan.md      ← Step 2 산출물
├── 03-refactor-plan.md  ← Step 3 산출물
└── 04-report.md         ← Step 6 산출물
```

- 같은 날짜+이름이 이미 존재하면 `-2`, `-3` 접미사 추가

---

## Step 1. 위반 진단

대상 코드를 규칙과 대조하여 **무엇이 위반되었는지** 구체적으로 파악한다. 이 단계에서는 수정하지 않는다 — 진단만 한다.

### 1-1. 아키텍처 위반 점검 (`--scope architecture` 또는 `all`)

`.claude/rules/core/architecture-essentials.md` 기준으로 점검한다:

- **FSD 역방향 의존**: 하위 레이어가 상위 레이어를 import하는지 (예: Entities → Features)
- **같은 레이어 간 import**: 동일 레이어 내 슬라이스 간 import가 있는지
- **Public API 우회**: `index.ts`를 거치지 않고 슬라이스 내부를 직접 import하는지
- **책임 혼재**: UI 컴포넌트에 비즈니스 로직이 있는지, Server Action에 UI 코드가 있는지
- **서버 로직 위치**: Server Actions/Route Handlers가 올바른 FSD 위치에 있는지

### 1-2. 컨벤션 위반 점검 (`--scope convention` 또는 `all`)

`.claude/rules/core/architecture-essentials.md` (네이밍 섹션) 기준으로 점검한다:

- **네이밍**: 파일명이 `kebab-case`가 아닌지, 컴포넌트가 `PascalCase`가 아닌지, 불리언에 `is`/`has`/`can`/`should` 접두사가 없는지
- **파일 크기**: 300줄 초과 파일
- **import 경로**: 깊은 상대 경로(`../../../`) 사용
- **TypeScript**: `any` 사용, 타입 단언 남용, 매직 넘버/문자열
- **컴포넌트 구조**: 클래스 컴포넌트 사용, props 인터페이스 미정의, 데이터 페칭과 렌더링 혼재
- **배럴 파일**: 기능 폴더 내부에 불필요한 `index.ts`

### 1-3. 품질 위반 점검 (`--scope quality` 또는 `all`)

`.claude/rules/core/architecture-essentials.md` + `.claude/rules/core/business-core-rules.md` 기준으로 점검한다:

- **에러 처리**: 빈 catch 블록, 인프라 에러가 Presentation까지 새어나오는지
- **유효성 검증**: 시스템 내부에서 불필요한 재검증, 스키마 라이브러리 미사용
- **코드 정확성**: `TODO`/`FIXME` 주석, 미사용 변수/import, 데드 코드
- **보안**: 하드코딩된 시크릿, SQL 직접 보간, 미검증 사용자 입력

### 1-4. 진단 보고서 작성

`01-diagnosis.md`에 작성한다:

```markdown
# 위반 진단 보고서: <대상명>

## Codex migration guardrails

- Treat this skill as a shared Claude Code ↔ Codex workflow. If source text mentions `.claude/`, Claude-only slash commands, or Claude-only tools, map them to the nearest project docs, `AGENTS.md`, `.codex/`, `.omc/`, native CLI, or available Codex skill/plugin surface.
- Prefer native CLI first for GitHub/Git work (`gh`, `git`) and do not publish issues, PRs, commits, Slack messages, or external side effects without explicit user intent/approval in the current task.
- Flag machine-specific absolute paths, usernames, local archives, and environment-specific assumptions as portability risks.
- Verify with concrete commands or generated evidence before claiming completion.


> 작성일: YYYY-MM-DD
> 대상: <파일/디렉토리 경로>
> 진단 범위: architecture | convention | quality | all

## 요약

- 대상 파일 수: N개
- 위반 항목 수: N개 (심각 N / 경미 N)

## 위반 목록

### [심각도: 높음] 위반 제목

- **규칙**: 어떤 규칙을 위반하는지 (규칙 파일명 + 항목)
- **위치**: `파일경로:줄번호`
- **현재 코드**: 위반하는 코드 스니펫
- **위반 사유**: 왜 이것이 규칙 위반인지 구체적으로

### [심각도: 낮음] 위반 제목

- ...

## 위반하지 않은 항목

<!-- 점검했지만 문제 없었던 영역 간략 기록 — 이후 회귀 테스트 범위 결정에 활용 -->
```

심각도 기준:
- **높음**: 아키텍처 레이어 위반, 보안 취약점, 데이터 흐름 오류
- **낮음**: 네이밍 컨벤션, 파일 크기, import 순서 등

`--gate diagnose`이면 여기서 멈추고 사용자에게 보고서를 안내한다.

---

## Step 2. 회귀 테스트 작성

리팩토링의 안전망을 구축한다. **리팩토링 전에 기존 동작을 테스트로 잠가야** 구조 변경 후에도 동작이 보존되었음을 증명할 수 있다.

### 2-1. 테스트 대상 식별

대상 코드에서 **외부에 노출된 인터페이스**를 파악한다 — 이것이 "동작 보존"의 기준선이다:

- **export된 함수/클래스**: 다른 모듈이 의존하는 공개 API
- **API 라우트 핸들러**: HTTP 요청/응답 계약
- **React 컴포넌트의 props → 렌더링 계약**: 특정 props가 주어졌을 때 기대하는 렌더링 결과
- **서비스 함수의 입출력**: 입력 값 → 반환 값 / 사이드 이펙트

### 2-2. 기존 테스트 확인

이미 존재하는 테스트를 확인하고, 커버리지 갭을 파악한다:

```bash
# 대상 파일과 관련된 기존 테스트 탐색
```

- 기존 테스트가 충분하면 → 새 테스트 작성 최소화 (기존 테스트가 회귀 테스트 역할)
- 기존 테스트가 없거나 부족하면 → 아래 2-3에서 작성

### 2-3. 회귀 테스트 작성

프로젝트 테스트 규칙(`.claude/references/testing-guide.md`)을 준수하여 작성한다:

**단위 테스트** (Vitest):
- 대상 파일과 같은 디렉토리에 `.test.ts` 파일 생성 (코로케이션 원칙)
- `describe` → `it` 구조, 테스트명은 동작 기술
- AAA 패턴 (Arrange → Act → Assert)
- 직접 제어하는 코드는 mock 금지 — 외부 의존성만 mock
- **현재 동작을 있는 그대로 캡처**: 리팩토링 전이므로 "올바른 동작"이 아니라 "현재 동작"을 기록

**통합 테스트** (필요한 경우):
- 레이어 간 연동이 리팩토링 대상일 때 작성
- API 라우트 핸들러 → 서비스 → 데이터 접근까지의 흐름을 테스트
- 외부 의존성(DB, 외부 API)만 mock

### 2-4. 테스트 실행 및 기준선 확립

```bash
npm test -- --run <관련 테스트 파일>
```

- 모든 회귀 테스트가 **통과**해야 한다 — 실패하면 테스트 코드를 수정 (현재 동작에 맞게)
- 이 시점의 테스트 결과가 **기준선(baseline)** — 리팩토링 후에도 이 결과가 동일해야 함

### 2-5. 테스트 계획 기록

`02-test-plan.md`에 작성한다:

```markdown
# 테스트 계획: <대상명>

> 작성일: YYYY-MM-DD

## 기존 테스트 현황

| 테스트 파일 | 유형 | 커버하는 기능 | 상태 |
| ----------- | ---- | ------------- | ---- |
| ...         | 단위 | ...           | 통과 |

## 새로 작성한 회귀 테스트

| 테스트 파일 | 유형 | 커버하는 기능 | 테스트 케이스 수 |
| ----------- | ---- | ------------- | ---------------- |
| ...         | 단위 | ...           | N개              |

## 기준선 결과

- 전체 테스트 수: N개
- 통과: N개
- 실패: 0개

## 리팩토링 후 추가 테스트 계획

<!-- 구조 변경 후 새로 추가해야 할 테스트 (새 모듈, 분리된 함수 등) -->
```

---

## Step 3. 리팩토링 계획

진단 결과와 테스트 안전망을 바탕으로, **어떻게 리팩토링할지** 계획을 세운다.

### 3-1. 리팩토링 단위 결정

위반 항목을 **독립적으로 실행 가능한 단위**로 묶는다. 한 번에 모든 것을 바꾸지 않는다 — 단위마다 테스트를 돌려 안전을 확인할 수 있어야 한다.

묶는 기준:
- 같은 파일에서 같은 유형의 위반 → 하나의 단위
- 의존 관계가 있는 위반 (A를 고쳐야 B를 고칠 수 있음) → 순서 포함하여 하나의 단위
- 서로 독립적인 위반 → 별도 단위

### 3-2. 실행 순서 결정

리팩토링 순서의 원칙:

1. **아키텍처 위반 먼저** — 레이어 구조가 바뀌면 다른 수정의 기반이 됨
2. **품질 위반 다음** — 에러 처리, 보안 등 동작에 영향을 줄 수 있는 것
3. **컨벤션 위반 마지막** — 네이밍, 파일 크기 등 구조적 영향이 적은 것

각 단위 실행 후 테스트를 돌려 동작 보존을 확인한다.

### 3-3. 리팩토링 계획서 작성

`03-refactor-plan.md`에 작성한다:

```markdown
# 리팩토링 계획: <대상명>

> 작성일: YYYY-MM-DD
> 기반: 01-diagnosis.md, 02-test-plan.md

## 리팩토링 단위

### 단위 1: <제목>

- **대상 위반**: #1, #2 (01-diagnosis.md 참조)
- **변경 파일**: ...
- **변경 내용**: ...
- **검증**: 테스트 실행 후 기준선과 동일한지 확인

### 단위 2: <제목>

- ...

## 실행 순서

1. 단위 1 → 테스트 검증
2. 단위 2 → 테스트 검증
3. ...

## 영향 범위

<!-- 이 리팩토링이 대상 외부에 미치는 영향 -->

| 외부 파일 | 영향 | 대응 |
| --------- | ---- | ---- |
| ...       | import 경로 변경 | import 수정 |

## 리스크

<!-- 동작이 변할 수 있는 지점과 대응책 -->
```

사용자에게 계획서를 제시하고 승인을 받는다. `--gate plan`이면 여기서 멈춘다.

---

## Step 4. 리팩토링 실행

승인된 계획에 따라 코드를 수정한다.

### 4-1. 단위별 실행

계획서의 순서대로 하나씩 진행한다. 각 단위마다:

1. **코드 수정**: 계획에 명시된 변경만 수행
2. **빌드 확인**: `npm run build && npm run lint:fix`
3. **회귀 테스트 실행**: `npm test -- --run <관련 테스트>`
4. **결과 확인**: 기준선과 동일하면 다음 단위로 진행, 실패하면 수정

단위 간에 빌드/테스트를 반드시 중간 확인한다 — 마지막에 몰아서 확인하지 않는다.

### 4-2. 실행 중 주의사항

- **계획에 없는 변경 금지**: 리팩토링 도중 발견한 다른 문제는 보고서에 기록만
- **동작 변경 금지**: 버그를 발견해도 이번 스코프에서는 구조만 수정. 버그 수정은 별도로
- **파일 이름 변경 시**: 해당 파일을 import하는 모든 파일의 경로도 함께 수정
- **DB 관련 변경 시**: `.claude/rules/core/db-essentials.md` 마이그레이션 워크플로우 준수

---

## Step 5. 테스트 검증

전체 리팩토링이 끝난 후, 포괄적으로 검증한다.

### 5-1. 회귀 테스트 전체 실행

```bash
npm test
```

- Step 2에서 작성한 회귀 테스트 + 기존 테스트 전체가 통과해야 한다
- 실패하는 테스트가 있으면 원인 분석 후 수정 (리팩토링 코드 수정, 테스트 수정이 아님)

### 5-2. 새 구조에 맞는 단위 테스트 추가

리팩토링으로 새로 생긴 모듈/함수에 대해 테스트를 추가한다:

- 파일 분리로 새 모듈이 생겼으면 → 해당 모듈의 단위 테스트
- 레이어 분리로 새 서비스/레포지토리가 생겼으면 → 인터페이스 기준 테스트
- 유틸 함수가 추출되었으면 → 입출력 기준 테스트

### 5-3. 통합 테스트 검증

레이어 구조가 변경된 경우:

- 레이어 간 연동이 정상 동작하는지 통합 테스트로 확인
- 기존 통합 테스트가 있으면 실행, 없으면 핵심 경로에 대해 작성

### 5-4. 빌드 최종 확인

```bash
npm run build
npm run lint:fix
```

---

## Step 6. 결과 보고서 작성

`04-report.md`에 전체 결과를 정리한다:

```markdown
# 리팩토링 결과 보고서: <대상명>

> 작성일: YYYY-MM-DD
> 대상: <파일/디렉토리 경로>
> 브랜치: <브랜치명>

## 1. 요약

<!-- 무엇을 왜 리팩토링했는지, 핵심 변경 사항 3~5줄 -->

## 2. 해결된 위반 항목

| # | 위반 항목 | 심각도 | 해결 방법 |
|---|-----------|--------|-----------|
| 1 | ...       | 높음   | ...       |

## 3. 변경 파일 목록

| 파일 | 변경 유형 | 설명 |
|------|-----------|------|
| ...  | 수정/신규/삭제/이름변경 | ... |

## 4. 테스트 결과

### 회귀 테스트

- 전체: N개
- 통과: N개
- 실패: 0개

### 새로 추가한 테스트

| 테스트 파일 | 유형 | 테스트 케이스 수 | 결과 |
|-------------|------|------------------|------|
| ...         | 단위 | N개              | 통과 |

### 빌드

- `npm run build`: PASS
- `npm run lint:fix`: PASS

## 5. 미해결 항목

<!-- 이번 스코프에서 다루지 않은 위반, 발견한 버그, 추가 리팩토링 필요 영역 -->

- [ ] ...

## 6. 후속 과업

- [ ] ...
```

---

## 완료 안내

```
.task/.refactoring/YYYY-MM-DD-<대상명>/   <- 현재 위치 (미커밋 상태)
  |- 01-diagnosis.md      위반 진단
  |- 02-test-plan.md      테스트 계획 및 기준선
  |- 03-refactor-plan.md  리팩토링 계획
  +- 04-report.md         결과 보고서

다음 단계:
- 보고서의 테스트 결과를 확인
- 미해결 항목이 있으면 추가 리팩토링 또는 이슈 생성
- 완료되면: /git-workflow 로 커밋 진행
```

---

## 참고: 이터레이션

이미 `.task/.refactoring/YYYY-MM-DD-<대상명>/` 폴더가 존재하고 사용자가 같은 대상에 대해 재호출하면:

1. 기존 산출물을 읽어 현재 어느 단계까지 진행됐는지 파악
2. `--gate` 옵션 또는 사용자 지시에 따라 특정 단계부터 재실행
3. 기존 파일을 덮어쓰기 전에 사용자에게 확인
