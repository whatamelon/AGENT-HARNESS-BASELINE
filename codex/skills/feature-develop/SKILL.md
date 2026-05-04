---
name: feature-develop
description: 피처 구현의 전체 사이클을 가이드한다 — 테스트 전략 → 구현 → 검증 → 결과 보고서 → E2E 검증 보고서(선택). 산출물이 필요한 대규모 구현, E2E 검증 보고서가 필요할 때, 스크린샷 캡처 기반 검증 산출물이 필요할 때 사용.
argument-hint: '<기능 설명 또는 .feature 폴더 경로> [--complexity simple|medium|complex] [--e2e|--no-e2e]'
---

사용자가 피처 구현을 요청했습니다: **$ARGUMENTS**

---

## 개요

이 스킬은 피처 구현의 전체 사이클을 가이드한다. 기획 산출물(`.feature/` 폴더)이 있으면 그걸 기반으로, 없으면 사용자 설명을 기반으로 진행한다.

```
[0] 컨텍스트 확인  →  [1] 테스트 전략  →  [2] 구현  →  [3] 검증  →  [4] 결과 보고서
                                                                    │
                                                        (사용자 확인) → [5] E2E 검증 보고서 + PDF
```

## 외부 스킬 적용

스택 프로파일(`references/stacks/`)에 명시된 외부 스킬을 적용한다. 프로파일이 없으면 프로젝트 CLAUDE.md의 기술 스택에서 관련 스킬을 판단한다.

## 가벼운 구현이 필요하면

간단한 기능 구현은 `/develop`를 사용한다. `/feature-develop`는 **테스트 전략·결과 보고서 등 공식 산출물이 필요한 대규모 구현**에 사용한다.

## 사전 준비 — 스택 감지 및 Reference Read

### 스택 프로파일 로드

1. 프로젝트 CLAUDE.md에서 기술 스택 정보를 읽는다
2. 이 스킬의 `references/stacks/` 에서 매칭되는 프로파일을 Read한다
   - 매칭 프로파일이 없으면 CLAUDE.md의 정보만으로 진행한다
3. 스택 프로파일의 빌드 명령·외부 스킬·아키텍처 규칙·코드 컨벤션을 이후 단계에서 사용한다

### 조건부 Reference Read

> 프로젝트에 아래 파일이 존재하면, 작업 유형에 따라 필요한 것만 Read한다. 이미 현재 세션에서 Read한 파일은 재읽기 불필요.

| 작업 유형 | Read (존재 시) |
|-----------|---------------|
| 모든 구현 | `.claude/references/architecture.md` |
| 프론트엔드 | + `.claude/references/frontend-guide.md` |
| API/서버 로직 | + `.claude/references/api-design.md` |
| 비즈니스 로직 | + `.claude/references/business-rules.md` |
| DB 변경 | + `.claude/references/db-schema.md` |

---

## Step 0. 컨텍스트 확인 및 환경 결정

### 0-1. 기획 산출물 확인

`.feature/` 폴더에서 관련 산출물을 찾는다:

1. `$ARGUMENTS`가 `.feature/` 경로를 직접 포함하면 해당 폴더 사용
2. 아니면 `.feature/` 하위에서 키워드로 매칭되는 폴더 탐색
3. 매칭되는 폴더가 있으면 기존 산출물(`01-analysis.md`, `02-design.md`, `04-plan.md` 등)을 읽어 컨텍스트로 활용
4. 없으면 `$ARGUMENTS`의 설명만으로 진행 — 이 경우 Step 1에서 코드 탐색을 더 깊게 수행

### 0-3. 출력 폴더 결정

기획 산출물 폴더가 있으면 같은 폴더에 추가한다:

```
.feature/YYYY-MM-DD-<기능명>/
├── 01-analysis.md       ← (기획 단계 산출물, 있으면 참조)
├── 02-design.md
├── 03-review.md
├── 04-plan.md
├── 05-test-strategy.md              ← Step 1 산출물
├── 06-dev-report.md                 ← Step 4 산출물
├── 07-issues.md                     ← Step 4 산출물
├── 08-e2e-verification-report.md    ← Step 5 산출물 (선택)
├── 08-e2e-verification-report.pdf   ← Step 5 PDF (선택)
└── _screenshots/                    ← Step 5 캡처 (선택)
```

기획 폴더가 없으면 새로 생성: `.feature/YYYY-MM-DD-<kebab-case-기능명>/`

---

## Step 1. 테스트 전략 결정

구현을 시작하기 전에, 이 기능에 어떤 수준의 테스트가 필요한지 판단하고 사용자에게 제안한다. 과잉 테스트도, 과소 테스트도 피해야 한다.

### 1-1. 복잡도 판단

`--complexity`가 명시되지 않았다면, 아래 기준으로 자동 판단한다:

| 신호               | simple | medium         | complex               |
| ------------------ | ------ | -------------- | --------------------- |
| 변경 파일 수       | 1~3개  | 4~8개          | 9개 이상              |
| DB 스키마 변경     | 없음   | 컬럼 추가 수준 | 테이블 신규/관계 변경 |
| 새로운 사용자 흐름 | 없음   | 기존 흐름 확장 | 완전히 새로운 흐름    |
| 외부 의존성        | 없음   | 기존 API 활용  | 신규 API 연동         |
| 기존 동작 영향     | 없음   | 제한적         | 광범위                |
| 권한/인증 관련     | 아니오 | 부분적         | 핵심                  |

### 1-2. 테스트 수준별 전략

#### Simple — "직접 확인이 가장 빠른 경우"

- 단위 테스트: 생략 (혹은 핵심 유틸 함수만)
- E2E 테스트: 생략
- UI E2E: 생략
- **대신**: 사용자에게 구체적인 수동 확인 체크리스트 제공
  - 어느 페이지에서 뭘 클릭하면 뭐가 보여야 하는지
  - 어떤 데이터로 테스트하면 되는지
  - 예상되는 결과가 무엇인지

#### Medium — "자동화된 기본 검증이 필요한 경우"

- 단위 테스트: 비즈니스 로직 함수, 유틸리티 함수
- E2E 테스트: 핵심 Happy Path 1~2개
- UI E2E: 생략 (수동 확인 체크리스트로 대체)

#### Complex — "체계적 검증이 필요한 경우"

- 단위 테스트: 비즈니스 로직 전체, 엣지 케이스 포함
- E2E 테스트: Happy Path + 주요 에러 시나리오
- UI E2E: 페르소나별 시나리오 (아래 Step 3-3 참조)

### 1-3. 사용자 확인

판단 결과를 `05-test-strategy.md`에 작성하고 사용자에게 제안한다:

```markdown
# 테스트 전략: <기능명>

## Codex migration guardrails

- Treat this skill as a shared Claude Code ↔ Codex workflow. If source text mentions `.claude/`, Claude-only slash commands, or Claude-only tools, map them to the nearest project docs, `AGENTS.md`, `.codex/`, `.omc/`, native CLI, or available Codex skill/plugin surface.
- Prefer native CLI first for GitHub/Git work (`gh`, `git`) and do not publish issues, PRs, commits, Slack messages, or external side effects without explicit user intent/approval in the current task.
- Flag machine-specific absolute paths, usernames, local archives, and environment-specific assumptions as portability risks.
- Verify with concrete commands or generated evidence before claiming completion.


> 작성일: YYYY-MM-DD
> 복잡도 판단: simple|medium|complex
> 판단 근거: ...

## 테스트 범위

### 단위 테스트

- [ ] 대상 함수/모듈 목록 (또는 "생략")

### E2E 테스트

- [ ] 시나리오 목록 (또는 "생략")

### UI E2E 테스트

- [ ] 페르소나 목록 및 시나리오 (또는 "수동 확인으로 대체")

### 수동 확인 체크리스트

- [ ] 항목별 확인 방법
```

사용자가 수준을 조정하면 반영한다 (예: "complex인데 UI E2E는 빼줘").

---

## Step 2. 구현

테스트 전략이 확정되면 구현을 진행한다.

### 2-1. 구현 진행

기획 산출물(`04-plan.md`)이 있으면 그 구현 계획을 따르고, 없으면 `$ARGUMENTS`를 기반으로 구현한다.

구현 전 프로젝트의 규칙 파일(`.claude/rules/`)을 확인하고 준수한다. 스택 프로파일에 규칙 파일 목록과 코드 컨벤션이 명시되어 있으면 해당 내용을 우선 참조한다.

프로젝트 규칙이 없으면 CLAUDE.md의 아키텍처·컨벤션 섹션을 기준으로 삼는다.

### 2-2. 테스트 코드 작성

테스트 전략에 따라 테스트 코드를 작성한다:

- **단위 테스트**: 프로젝트 컨벤션에 따라 대상 함수 근처에 테스트 파일 배치
- **E2E 테스트**: 시나리오별 테스트 파일

---

## Step 3. 검증

### 3-1. 빌드 검증

프로젝트의 빌드·린트 명령을 실행한다. 명령은 다음 순서로 확인:
1. 스택 프로파일의 "빌드·검증 명령" 섹션
2. 프로젝트 CLAUDE.md의 "자주 쓰는 명령어" 섹션
3. 프로젝트 루트의 설정 파일(`package.json`, `Makefile`, `pyproject.toml` 등)에서 추론

빌드 실패 시 수정 후 재검증. 통과할 때까지 반복한다.

### 3-2. 테스트 실행

테스트 전략에 맞게 실행한다. 테스트 명령은 스택 프로파일 또는 CLAUDE.md에서 확인:

- **단위 테스트**: 프로젝트의 단위 테스트 명령 실행 또는 대상 파일 직접 실행
- **E2E 테스트**: 시나리오별 실행 및 결과 수집

### 3-3. UI E2E 테스트 (complex인 경우)

complex 수준에서 UI E2E가 포함된 경우, **페르소나 기반 UI 검증**을 수행한다.

#### 페르소나 정의

기능의 사용자 유형에 따라 UI 테스트 페르소나를 정의한다. 이 페르소나는 기술 직군이 아니라 **실제 사용자 유형**이다:

| 예시 페르소나 | 관점                      | 시나리오 초점          |
| ------------- | ------------------------- | ---------------------- |
| 신규 사용자   | 처음 접하는 UI의 직관성   | 온보딩, 첫 사용 흐름   |
| 파워 유저     | 효율성, 단축키, 대량 작업 | 반복 작업, 대량 데이터 |
| 관리자        | 권한 관리, 전체 현황 파악 | 설정, 대시보드, 권한   |
| 모바일 사용자 | 터치 인터페이스, 반응형   | 좁은 화면, 터치 제스처 |

#### 실행 방식

각 페르소나별로 **서브에이전트를 병렬 실행**한다:

- Playwright 기반: `/e2e-qa-report` 스킬 활용 가능
- Maestro 기반: 모바일 앱 대상일 때 Maestro 스크립트 생성/실행

각 서브에이전트에게 전달할 프롬프트:

```
당신은 "{페르소나명}" 사용자입니다.
아래 기능을 실제로 사용하면서 문제가 없는지 검증하세요.

## 기능 설명
{기능 요약}

## 테스트 시나리오
{페르소나별 시나리오 목록}

## 검증 항목
- 의도한 흐름이 정상 동작하는가
- 에러 메시지가 적절한가
- UI가 깨지지 않는가 (레이아웃, 반응형)
- 콘솔 에러가 없는가
- 네트워크 에러(4xx/5xx)가 없는가

## 출력
- 스크린샷 (주요 화면)
- 발견된 이슈 목록 (심각도 포함)
- 통과/실패 시나리오 요약
```

#### 이터레이션

UI E2E에서 이슈가 발견되면:

1. 이슈 목록을 사용자에게 보고
2. 사용자 확인 후 수정
3. 수정 후 해당 시나리오만 재실행
4. 모든 시나리오 통과 또는 사용자가 "충분하다"고 판단할 때까지 반복

---

## Step 4. 결과 보고서 작성

모든 검증이 끝나면 두 개의 문서를 `.feature/` 폴더에 작성한다.

### 4-1. 구현 결과 보고서 (`06-dev-report.md`)

```markdown
# 구현 결과 보고서: <기능명>

> 작성일: YYYY-MM-DD
> 복잡도: simple|medium|complex
> 브랜치: <브랜치명>

## 1. 구현 요약

<!-- 무엇을 구현했는지 3~5줄 -->

## 2. 변경 파일 목록

| 파일 | 변경 유형      | 설명 |
| ---- | -------------- | ---- |
| ...  | 신규/수정/삭제 | ...  |

## 3. 검증 결과

### 빌드

- 빌드: ✅ 통과 / ❌ 실패 사유
- 린트: ✅ 통과 / ❌ 실패 사유

### 단위 테스트

<!-- 결과 요약 또는 "생략 (simple)" -->

### E2E 테스트

<!-- 시나리오별 통과/실패 또는 "생략" -->

### UI E2E 테스트

<!-- 페르소나별 결과 요약 또는 "수동 확인으로 대체" -->

## 4. 사용자 확인 가이드

이 기능을 직접 확인하려면:

### 사전 조건

<!-- 필요한 데이터, 권한, 환경 -->

### 확인 절차

1. ...에 접속
2. ...를 클릭
3. ...가 표시되는지 확인
4. ...

### 예상 결과

<!-- 정상 동작 시 보여야 하는 것 -->

## 5. 후속 과업

- [ ] 과업 1: ...
- [ ] 과업 2: ...
```

### 4-2. 핵심 이슈 및 요청사항 (`07-issues.md`)

구현 과정에서 발견했지만 이번 스코프에서 해결하지 않은 것들, 또는 사용자/팀에게 전달해야 할 사항:

```markdown
# 핵심 이슈 및 요청사항: <기능명>

> 작성일: YYYY-MM-DD

## 발견된 이슈

### [심각도: 높음/중간/낮음] 이슈 제목

- **현상**: ...
- **원인 (추정)**: ...
- **영향 범위**: ...
- **권장 조치**: ...

## 기술 부채

<!-- 구현 과정에서 발견한, 이번에 해결하지 않은 기술 부채 -->

## 요청사항

<!-- 다른 팀원/팀에 전달할 사항 -->

- [ ] 디자인 확인 필요: ...
- [ ] API 변경 요청: ...
- [ ] 인프라 설정 필요: ...

## 참고사항

<!-- 다음 작업자를 위한 메모 -->
```

---

## Step 5. E2E 검증 보고서 (선택)

구현 완료 후, dev 서버에서 실제 화면을 캡처하여 요구사항 조견표 + 스크린샷 PDF를 생성한다. 이해관계자에게 "잘 만들어졌다"를 시각적으로 증명하는 산출물이다.

### 5-0. 진행 여부 확인

- `--e2e`: 질문 없이 바로 진행
- `--no-e2e`: 건너뜀
- 미지정 시 사용자에게 묻는다:

> **E2E 검증 보고서를 작성하시겠습니까?** dev 서버를 띄워 Playwright로 주요 화면을 캡처하고, 요구사항 조견표 + 스크린샷 PDF를 생성합니다. (y/n)

`n`이면 완료 안내로 간다.

### 5-1. 환경 준비

1. dev 서버 기동 (스택 프로파일 또는 CLAUDE.md의 개발 서버 명령 참조) — 이미 실행 중이면 스킵
2. **Playwright MCP 사용** (클린 세션, 쿠키 축적 없음). Chrome MCP는 HTTP 431 등 세션 이슈가 발생할 수 있으므로 Playwright 우선.
3. 로그인이 필요하면: env에서 관련 credentials를 읽어 로그인 수행
4. 빌드 에러로 페이지 로딩 불가 시 → 사용자에게 에러 보고 후 중단

### 5-2. 캡처 계획 수립

`04-plan.md` (또는 `06-dev-report.md`)에서 UI 변경이 있는 화면 목록을 추출하고, 각 화면에 대해 캡처 계획을 세운다:

| 항목 | 결정 |
|------|------|
| URL | 네비게이션 경로 |
| 인터랙션 | 캡처 전 수행할 동작 (필터 열기, 탭 전환, 모달 열기 등) |
| 뷰포트 | 데스크탑(1440x900) 또는 모바일(390x844) |
| 파일명 | `_screenshots/NN-kebab-description.png` |

모바일 화면은 viewport 리사이즈 + `setExtraHTTPHeaders` 로 모바일 User-Agent를 설정하여 모바일 라우트에 접근한다:

```javascript
await context.setExtraHTTPHeaders({
  'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) ...'
});
```

### 5-3. 스크린샷 캡처 실행

캡처 계획에 따라 순차 실행:

```
navigate → wait(3s) → interact(선택) → screenshot(fullPage)
```

- 파일 저장 경로: `.feature/<기능명>/_screenshots/` (Playwright 허용 경로에 따라 조정)
- 실패 시 2회 재시도 후 스킵 + 사용자 보고
- 캡처 완료 후 파일 목록 확인 (`ls _screenshots/`)

### 5-4. 보고서 작성

`references/e2e-report-template.md` 를 Read 하고 `08-e2e-verification-report.md` 를 작성한다.

핵심 구조:

1. **표지/메타** — 요청자, 검증일, 브랜치
2. **§1 요구사항 조견표** — 원본 요청서/`04-plan.md`에서 요구사항 추출 → 마스터 테이블 (요구사항 | 구현 상태 | 검증 결과 | 비고) + 세부 항목별 테이블
3. **§2 E2E 스크린샷** — 화면별 캡처 이미지 `![캡션](_screenshots/NN-name.png)` + 확인 포인트 불릿
4. **§3 빌드 검증** — build/lint/test 결과
5. **§4 리뷰 반영 결과** — `03-review.md` 기반 (있는 경우)
6. **§5 미해결 사항** — 보류/후속 과업
7. **§6 결론** — 3~5줄 종합 판단

이미지 경로는 **상대 경로** (`_screenshots/...`) 사용 — md-to-pdf가 같은 디렉토리 기준으로 해석한다.

### 5-5. PDF 생성

```bash
npx md-to-pdf "08-e2e-verification-report.md" \
  --launch-options '{"args":["--no-sandbox"]}' \
  --stylesheet "<feature-review 또는 request-start의 pdf-styling.css>" \
  --pdf-options '{"format":"A4","margin":{"top":"20mm","right":"15mm","bottom":"20mm","left":"15mm"},"printBackground":true}' \
  --highlight-style "github" \
  --document-title "<기능명> E2E 검증 보고서"
```

회귀 검증:

```bash
pdftotext "08-e2e-verification-report.pdf" - | grep -cE '<div class=|<section class='
# → 0건
pdfimages -list "08-e2e-verification-report.pdf" | tail -n +3 | wc -l
# → 캡처 수 이상
```

### 5-6. 결과 보고

```
✅ E2E 검증 보고서 생성 완료

📁 .feature/<기능명>/
  ├── 08-e2e-verification-report.md   (NN줄)
  ├── 08-e2e-verification-report.pdf  (NN페이지, NN MB, 이미지 N장)
  └── _screenshots/                    (N장)

검증
  - raw HTML 누출: 0건
  - 임베딩 이미지: N장
  - 요구사항 조견표: N건 중 N건 통과
```

---

## 완료 안내

모든 단계가 끝나면 실제로 생성된 파일만 체크 표시해서 안내한다:

```
📁 .feature/YYYY-MM-DD-<기능명>/   ← 현재 위치 (미커밋 상태)
  ├── 01~04 (기획 산출물, 있는 경우)
  ├── 05-test-strategy.md              ✅ 테스트 전략
  ├── 06-dev-report.md                 ✅ 구현 결과 보고서
  ├── 07-issues.md                     ✅ 핵심 이슈 및 요청사항
  ├── 08-e2e-verification-report.md    ✅ E2E 검증 보고서 (Step 5 실행 시)
  ├── 08-e2e-verification-report.pdf   ✅ PDF (Step 5 실행 시)
  └── _screenshots/                    ✅ 캡처 (Step 5 실행 시)

다음 단계:
- 결과 보고서의 "사용자 확인 가이드"에 따라 직접 확인
- 이슈가 있으면 수정 후 이터레이션 가능
- 완료되면: /git-workflow 로 커밋 진행
  → 커밋 후 자동으로 .feature/archives/<기능명>/ 으로 이동됨
```
