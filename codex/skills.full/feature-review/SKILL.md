---
name: feature-review
description: 피처의 전체 기획 사이클을 실행한다 — 현황 분석 → 설계 → 페르소나 리뷰 → 플랜 → UI 데모 → PDF 설계서
argument-hint: '<기능 설명> [--gate analysis|design|review|plan|demo|pdf] [--depth shallow|deep] [--demo|--no-demo] [--pdf|--no-pdf]'
---

사용자가 피처 기획을 요청했습니다: **$ARGUMENTS**

---

## 개요

이 스킬은 피처 기획의 전체 사이클을 순차 실행하고, 각 단계의 산출물을 `.feature/` 폴더에 저장한다.

```
[1] 현황 분석 → [2] 피처 설계 → [3] 페르소나 리뷰 → [4] 최종 플랜
                                                          │
                                                          ▼
                                      (사용자 확인) → [5] HTML UI 데모
                                                          │
                                                          ▼
                                      (사용자 확인) → [6] PDF 종합 설계서
```

각 단계는 이전 단계의 산출물 위에 쌓인다. Step 5·6은 플랜 확정 직후 사용자에게 생성 여부를 묻는 것이 기본이며, `--demo`/`--no-demo`, `--pdf`/`--no-pdf` 플래그로 질문을 건너뛸 수 있다. `--gate` 옵션으로 특정 단계에서 멈출 수 있다.

## 외부 스킬 적용

스택 프로파일(`references/stacks/`)에 명시된 외부 스킬을 적용한다. 프로파일이 없으면 프로젝트 CLAUDE.md의 기술 스택에서 관련 스킬을 판단한다.

## 사전 준비 — 스택 감지 및 Reference Read

### 스택 프로파일 로드

1. 프로젝트 CLAUDE.md에서 기술 스택 정보를 읽는다
2. 이 스킬의 `references/stacks/` 에서 매칭되는 프로파일을 Read한다
   - Next.js + Supabase → `references/stacks/next-supabase.md`
   - 매칭 프로파일이 없으면 CLAUDE.md의 정보만으로 진행한다
3. 스택 프로파일이 있으면 거기에 명시된 외부 스킬·규칙 파일·아키텍처 패턴을 이후 단계에서 적용한다

### 조건부 Reference Read

> 프로젝트에 아래 파일이 존재하면, 작업 유형에 따라 필요한 것만 Read한다. 이미 현재 세션에서 Read한 파일은 재읽기 불필요.

| 분석 영역 | Read (존재 시) |
|-----------|---------------|
| 모든 기획 | `.claude/references/architecture.md`, `.claude/references/business-rules.md` |
| DB 변경 포함 | + `.claude/references/db-schema.md` |
| API 설계 포함 | + `.claude/references/api-design.md` |
| 프론트엔드 포함 | + `.claude/references/frontend-guide.md` |

## 가벼운 기획이 필요하면

간단한 기능 설계는 `/plan`(Plan Mode)을 사용한다. `/feature-review`는 **공식 산출물(분석서·설계서·리뷰·PDF)이 필요한 경우**에 사용한다.

---

## Step 0. 인자 파싱 및 출력 폴더 생성

`$ARGUMENTS`에서 다음을 추출한다:

| 인자          | 기본값 | 설명                                                                                |
| ------------- | ------ | ----------------------------------------------------------------------------------- |
| `<기능 설명>` | (필수) | 분석/설계할 기능의 자유 형식 설명                                                   |
| `--gate`      | `pdf`  | 어디서 멈출지: `analysis`, `design`, `review`, `plan`, `demo`, `pdf`                |
| `--depth`     | `deep` | 리뷰 깊이: `shallow`(설계 수준만), `deep`(코드 라인 레벨까지)                       |
| `--demo`      | (ask)  | Step 5(HTML UI 데모) 강제 생성. `--no-demo` 로 건너뜀. 미지정 시 사용자에게 질문    |
| `--pdf`       | (ask)  | Step 6(PDF 설계서) 강제 생성. `--no-pdf` 로 건너뜀. 미지정 시 사용자에게 질문       |

- `--gate plan`: Step 4까지 실행 후 종료 (Step 5·6 질문 생략)
- `--gate demo`: Step 5까지 실행 후 종료 (PDF 생성 생략)
- `--gate pdf`: Step 6까지 모두 실행 (기본값, 단 각 단계 질문은 유지)

### 폴더 생성

```
.feature/YYYY-MM-DD-<kebab-case-기능명>/
├── 01-analysis.md      ← Step 1 산출물
├── 02-design.md        ← Step 2 산출물
├── 03-review.md        ← Step 3 산출물
├── 04-plan.md          ← Step 4 산출물
├── 05-ui-demo.html     ← Step 5 산출물 (선택)
├── 05-ui-demo.md       ← Step 5 마크다운 래퍼 (선택)
├── feature-design.md   ← Step 6 PDF 빌드용 통합 md (선택, 보존)
└── feature-design.pdf  ← Step 6 최종 산출 (선택)
```

- 날짜는 오늘 날짜 사용
- `<kebab-case-기능명>`은 기능 설명에서 핵심 키워드 2~4개를 뽑아 kebab-case로 구성
- 같은 날짜+이름이 이미 존재하면 `-2`, `-3` 등 접미사 추가

폴더를 먼저 생성한 후 진행한다.

---

## Step 1. 현황 분석 (Analysis)

이 단계의 목적은 피처와 관련된 현재 상태를 철저히 파악하는 것이다. 잘 된 현황 분석이 있어야 이후 설계와 리뷰가 의미 있다.

### 1-1. 컨텍스트 수집

아래 항목을 **반드시** 조사한다. 항목마다 Explore 에이전트나 직접 도구를 사용해 실제 코드와 문서를 읽는다:

**코드 현황**

- 관련 파일/컴포넌트 목록 (경로 + 줄 수 + 핵심 역할)
- 현재 구현 상태 (미구현 / 부분 구현 / 완전 구현)
- 관련 API 라우트, 서비스, 데이터 액세스 레이어
- 사용 중인 외부 라이브러리/의존성

**아키텍처 현황**

- 프로젝트 아키텍처 레이어에서의 위치 (스택 프로파일 또는 `.claude/rules/` 참조)
- 관련 DB 테이블/스키마 (있다면)
- 상태 관리 방식 (클라이언트/서버)

**도메인 현황**

- `.claude/references/business-rules.md` 내 관련 도메인 규칙
- 기존 유사 기능의 구현 패턴
- 기존 유사 기능이 있다면 그 구현 패턴

**컨벤션 및 아키텍처 규칙**

- 프로젝트의 `.claude/rules/` 규칙 파일을 확인한다 (스택 프로파일에 목록이 있으면 참조)
- 프로젝트 규칙이 없으면 CLAUDE.md의 아키텍처·컨벤션 섹션을 기준으로 삼는다
- 현황 분석 시 기존 코드가 이 규칙을 얼마나 준수하는지도 기록

**이슈/히스토리**

- 관련 GitHub 이슈가 있는지 확인 (`gh issue list --search "키워드"`)
- 최근 관련 커밋 히스토리 (`git log --oneline --grep="키워드"`)

### 1-2. 현황 분석 보고서 작성

수집한 내용을 `01-analysis.md`에 작성한다:

```markdown
# 현황 분석: <기능명>

## Codex migration guardrails

- Treat this skill as a shared Claude Code ↔ Codex workflow. If source text mentions `.claude/`, Claude-only slash commands, or Claude-only tools, map them to the nearest project docs, `AGENTS.md`, `.codex/`, `.omc/`, native CLI, or available Codex skill/plugin surface.
- Prefer native CLI first for GitHub/Git work (`gh`, `git`) and do not publish issues, PRs, commits, Slack messages, or external side effects without explicit user intent/approval in the current task.
- Flag machine-specific absolute paths, usernames, local archives, and environment-specific assumptions as portability risks.
- Verify with concrete commands or generated evidence before claiming completion.


> 분석일: YYYY-MM-DD
> 대상: <기능 설명 요약>

## 1. 현재 상태 요약

<!-- 3~5줄로 현재 어떤 상태인지 -->

## 2. 관련 코드 맵

<!-- 파일 경로, 줄 수, 역할을 테이블로 -->

| 파일 | 줄 수 | 역할 | 비고 |
| ---- | ----- | ---- | ---- |
| ...  | ...   | ...  | ...  |

## 3. 아키텍처 현황

<!-- 레이어별 현황, DB 스키마, 상태 관리 -->

## 4. 도메인 컨텍스트

<!-- 관련 도메인 규칙, 기존 패턴 -->

## 5. 관련 이슈 및 히스토리

<!-- GitHub 이슈, 최근 커밋 -->

## 6. 제약 사항 및 리스크

<!-- 기술적 제약, 의존성 리스크, 호환성 이슈 -->

## 7. 분석 소견

<!-- 현황을 바탕으로 한 핵심 인사이트 3~5개 -->
```

`--gate analysis`이면 여기서 멈추고 사용자에게 보고서를 안내한다.

---

## Step 2. 피처 설계 (Design)

현황 분석을 바탕으로 기능의 설계안을 작성한다.

### 2-1. 설계 문서 작성

`02-design.md`에 작성한다:

```markdown
# 피처 설계: <기능명>

> 설계일: YYYY-MM-DD
> 기반: 01-analysis.md

## 1. 목표

<!-- 이 기능이 해결하는 문제와 기대 효과 -->

## 2. 스코프

### In-Scope

<!-- 이번에 구현할 것 -->

### Out-of-Scope

<!-- 의도적으로 제외하는 것과 그 이유 -->

## 3. 설계안

### 3.1 사용자 흐름 (User Flow)

<!-- 사용자 관점의 단계별 흐름 -->

### 3.2 컴포넌트 설계

<!-- 새로 만들거나 수정할 컴포넌트 -->

### 3.3 데이터 모델

<!-- 새로운/변경될 DB 스키마, API 응답 구조 -->

### 3.4 API 설계

<!-- 새로운/변경될 엔드포인트 -->

### 3.5 상태 관리

<!-- 클라이언트/서버 상태 전략 -->

## 4. 구현 전략

### 변경 파일 목록

<!-- 레이어별로 정리 -->

### 구현 순서

<!-- 의존성 고려한 단계별 순서 -->

### 마이그레이션 (해당 시)

<!-- DB 스키마 변경 내용 -->

## 5. 대안 및 트레이드오프

<!-- 고려한 다른 접근법과 현재 안을 선택한 이유 -->
```

`--gate design`이면 여기서 멈추고 사용자에게 설계 문서를 안내한다.

---

## Step 3. 페르소나 리뷰 (Review)

설계안을 다양한 전문가 관점에서 리뷰한다. 핵심은 각 페르소나가 **자기 전문 영역의 렌즈**로만 집중해서 보는 것이다. 범용적인 피드백은 가치가 낮다.

### 3-1. 페르소나 선정

기능의 성격에 따라 아래 후보군에서 **3~5명**을 선정한다. 모든 기능에 모든 페르소나가 필요하진 않다 — 해당 기능과 관련이 깊은 전문가만 골라야 리뷰 품질이 높아진다.

| 페르소나                 | 전문 영역                                        | 이런 기능일 때 선정                            |
| ------------------------ | ------------------------------------------------ | ---------------------------------------------- |
| **CEO / 사업 관점**      | 비즈니스 임팩트, ROI, 시장 적합성, 우선순위      | 사업 방향에 영향을 주는 기능, 신규 사용자 흐름 |
| **PM (프로덕트 매니저)** | 요구사항 완전성, 사용자 스토리, 우선순위, 스코프 | 모든 기능 (기본 포함)                          |
| **UX 디자이너**          | 사용성, 접근성, 인터랙션 패턴, 정보 구조         | UI가 포함된 기능                               |
| **프론트엔드 개발자**    | 컴포넌트 구조, 성능, 상태 관리, 렌더링 전략      | 클라이언트 사이드 변경이 있는 기능             |
| **백엔드 개발자**        | API 설계, 데이터 모델, 비즈니스 로직, 확장성     | 서버 사이드 변경이 있는 기능                   |
| **DBA**                  | 스키마 설계, 쿼리 성능, 인덱싱, 데이터 무결성    | DB 스키마 변경이 있는 기능                     |
| **QA 엔지니어**          | 테스트 전략, 엣지 케이스, 회귀 리스크            | 복잡한 로직, 기존 동작 변경                    |
| **보안 엔지니어**        | 인증/인가, 입력 검증, 데이터 보호                | 인증, 권한, 사용자 데이터 관련 기능            |
| **DevOps**               | 배포 전략, 인프라 영향, 모니터링                 | 인프라 변경, 새로운 외부 의존성                |

선정 기준을 `03-review.md` 상단에 기록한다 (왜 이 페르소나들을 골랐는지).

### 3-2. 병렬 리뷰 실행

선정된 각 페르소나에 대해 **Agent 도구로 서브에이전트를 병렬 실행**한다.

각 서브에이전트에게 전달할 프롬프트:

```
당신은 {페르소나명}입니다. 아래 피처 설계를 당신의 전문 영역 관점에서 리뷰하세요.

## 당신의 역할과 관점
{페르소나별 전문 영역 설명}

## 리뷰 대상
- 현황 분석: {01-analysis.md 전문}
- 설계 문서: {02-design.md 전문}

## 리뷰 깊이: {shallow|deep}
- shallow: 설계 문서 수준에서 전략적 피드백
- deep: 관련 코드를 직접 읽고 구현 수준의 구체적 피드백 (파일 경로, 줄 번호 포함)

## 출력 형식
아래 형식으로 리뷰를 작성하세요:

### {페르소나명} 리뷰

**평가**: 🟢 좋음 / 🟡 개선 필요 / 🔴 재설계 필요

**강점** (2~3개)
- ...

**우려 사항** (구체적으로, 우선순위 높은 순)
1. [심각도: 높음/중간/낮음] ...
2. ...

**제안** (실행 가능한 수준으로)
1. ...

**놓친 부분** (다른 리뷰어가 간과할 수 있는, 이 전문 영역에서만 보이는 것)
- ...
```

### 3-3. 리뷰 취합

모든 서브에이전트 결과를 `03-review.md`에 통합한다:

```markdown
# 페르소나 리뷰: <기능명>

> 리뷰일: YYYY-MM-DD
> 리뷰 깊이: shallow|deep
> 기반: 01-analysis.md, 02-design.md

## 페르소나 선정 근거

<!-- 왜 이 페르소나들을 골랐는지 -->

---

## 리뷰 결과

### {페르소나 1} 리뷰

<!-- 서브에이전트 결과 그대로 -->

### {페르소나 2} 리뷰

<!-- ... -->

---

## 크로스 커팅 분석

<!-- 여러 페르소나에서 공통으로 나온 우려, 상충하는 의견, 컨센서스 -->

### 공통 우려 사항

- ...

### 의견 충돌

- ...

### 컨센서스

- ...
```

`--gate review`이면 여기서 멈추고 사용자에게 리뷰 결과를 안내한다.

---

## Step 4. 최종 피처 플랜 (Plan)

현황 분석 + 설계 + 리뷰를 종합하여 실행 가능한 최종 계획을 작성한다.

`04-plan.md`에 작성한다:

```markdown
# 피처 플랜: <기능명>

> 작성일: YYYY-MM-DD
> 기반: 01-analysis.md, 02-design.md, 03-review.md

## 1. 최종 결정 사항

<!-- 리뷰 피드백을 반영한 최종 설계 결정 -->
<!-- 각 결정에 대해: 무엇을 / 왜 / 어떤 리뷰 피드백을 반영했는지 -->

## 2. 최종 스코프

### 포함

- ...

### 제외 (사유)

- ...

### 후속 과제 (이번에 안 하지만 나중에 할 것)

- ...

## 3. 구현 계획

### Phase 1: ...

- [ ] 작업 1 — 파일: `경로`, 예상 변경
- [ ] 작업 2 — ...

### Phase 2: ...

- [ ] ...

## 4. 리스크 및 대응

| 리스크 | 발생 가능성 | 영향도 | 대응 방안 |
| ------ | ----------- | ------ | --------- |
| ...    | ...         | ...    | ...       |

## 5. 검증 계획

<!-- 어떻게 이 기능이 제대로 동작하는지 확인할 것인지 -->

## 6. 리뷰 반영 이력

<!-- 어떤 리뷰 피드백을 수용/거절했는지와 그 이유 -->

| 피드백 | 출처 | 반영 여부 | 사유 |
| ------ | ---- | --------- | ---- |
| ...    | ...  | ✅/❌     | ...  |
```

`--gate plan`이면 여기서 멈추고 Step 5·6 질문을 하지 않는다.

---

## Step 5. HTML UI 데모 (선택)

플랜이 확정된 뒤에도 이해관계자는 텍스트 문서만으로는 변경을 체감하기 어렵다. 이 단계는 As-Is · To-Be · 변경점을 **시각적으로 겹쳐서** 보여주는 정적 HTML 을 만들어 이 간극을 메운다.

### 5-1. 진행 여부 확인

- `--no-demo` 가 지정됐으면 Step 5·6 모두 건너뛰고 완료 안내로 간다.
- `--demo` 가 지정됐으면 질문 없이 바로 5-2로 진행.
- 아무 플래그도 없으면 사용자에게 묻는다:

  > **UI 데모를 생성할까요?** (As-Is / To-Be / 변경점을 시각화한 HTML + PDF 임베딩용 마크다운을 만듭니다. y/n)

  `n` 이면 완료 안내로 간다. `y` 이면 5-2로 진행.

### 5-2. 템플릿과 가이드 로드

아래 두 파일을 Read 로 불러온다 (대용량 템플릿·규칙을 본문에 넣지 않는 progressive disclosure 원칙):

- `.claude/skills/feature-review/references/ui-demo-template.html` — 상하 스택 + 사이드 메모 레이아웃, 하이라이트 클래스(`.added`/`.changed`/`.removed`) 포함
- `.claude/skills/feature-review/references/ui-demo-guide.md` — 하이라이트 규칙, 컨텍스트 소스 매핑, As-Is 없는 신규 기능 처리법, 좋은/나쁜 예시

### 5-3. 산출물 작성

가이드의 "컨텍스트 소스 매핑" 표에 따라 `01-analysis.md`, `02-design.md`, `04-plan.md` 에서 정보를 뽑아 다음 두 파일을 만든다:

1. **`05-ui-demo.html`** — 템플릿의 `{{FEATURE_NAME}}`, `{{DATE}}`, `{{SCREEN_NAME}}` 등 플레이스홀더를 실제 값으로 치환. 변경된 요소에만 `.added` / `.changed` / `.removed` 클래스를 부여한다. 화면이 여러 개면 `section.screen-block` 을 복제한다.

2. **`05-ui-demo.md`** — HTML의 `<body>` 내부(중복되는 `<h1 class="demo-title">` 제거)를 `<div class="feature-demo">...</div>` 로 감싸 임베딩한 마크다운. 상단에 "핵심 변경 요약" · 하단에 "화면별 상세(문장형)" 를 둬서 검색/목차에서 인식되게 한다.

두 파일 모두 `.feature/YYYY-MM-DD-<기능명>/` 아래에 저장한다.

### 5-4. 게이트 확인

`--gate demo` 이면 Step 6 질문을 생략하고 완료 안내로 간다.

---

## Step 6. PDF 종합 설계서 (선택)

공유·결재용 단일 산출물을 만든다. 표지 + 플랜 + UI 데모 + 설계 + 리뷰 + 현황 분석 부록까지 하나의 PDF에 담는다.

### 6-1. 진행 여부 확인

- `--no-pdf` 면 건너뛴다.
- `--pdf` 면 질문 없이 6-2로 진행.
- 아무 플래그도 없으면 사용자에게 묻는다:

  > **PDF 종합 설계서를 만들까요?** (01~05 산출물을 하나의 PDF로 패키징합니다. y/n)

### 6-2. 절차 문서 로드

아래 두 파일을 Read 한다:

- `.claude/skills/feature-review/references/pdf-packaging.md` — 통합 md 챕터 순서, md-to-pdf 호출 플래그, 실패 복구
- `.claude/skills/feature-review/references/pdf-styling.css` — 패키징에 적용되는 스타일 (직접 수정하지 않음)

### 6-3. 통합 마크다운 생성

`feature-design.md` 를 기능 폴더에 작성한다. `pdf-packaging.md`의 "통합 마크다운 구조" 를 따라 챕터 순서를 배치한다:

1. 표지 (`.cover` div — 기능명·날짜·기반 산출물 목록)
2. Chapter 1 — `04-plan.md` 원문
3. Chapter 2 — UI 변경 데모 (`05-ui-demo.html` body 를 `.feature-demo` div 로 임베딩)
4. Chapter 3 — `02-design.md` 원문
5. Chapter 4 — `03-review.md` 원문
6. Appendix — `01-analysis.md` 원문

각 챕터는 `<div class="chapter">` 로 감싸 페이지 브레이크가 걸리게 한다.

**⚠ Chapter 2 임베딩 — HTML 정규화 필수.** `05-ui-demo.html`의 `<body>` 내부를 들여쓰기·빈 줄을 그대로 둔 채 복붙하면 PDF의 To-Be 블록 등 일부 영역이 raw HTML 코드로 출력된다. 이유와 처리 방법은 `pdf-packaging.md` 의 "⚠ Chapter 2 UI 데모 임베딩 — HTML 정규화 필수" 절 참조. 요지: 임베딩 영역 전체에 leading whitespace 제거 + 빈 줄 제거 (예: `sed -e 's/^[[:space:]]*//' -e '/^$/d'`)를 적용한 후 `<div class="feature-demo">` 안에 넣는다.

### 6-4. md-to-pdf 실행

`/md-to-pdf` 스킬의 기본 호출을 기반으로 하되, 스타일시트와 페이지 옵션을 추가한다:

```bash
npx md-to-pdf "<feature-dir>/feature-design.md" \
  --launch-options '{"args":["--no-sandbox"]}' \
  --stylesheet "<repo-root>/.claude/skills/feature-review/references/pdf-styling.css" \
  --pdf-options '{"format":"A4","margin":{"top":"20mm","right":"15mm","bottom":"20mm","left":"15mm"},"printBackground":true}' \
  --highlight-style "github" \
  --document-title "<기능명> 설계서"
```

실패 시 `pdf-packaging.md` 의 "실패 복구" 표를 참조한다 (`printBackground` 누락, Puppeteer sandbox, 한글 폰트 등).

### 6-4a. 회귀 검증 — raw HTML 누출 확인

PDF 변환 직후 다음을 실행한다:

```bash
pdftotext "<feature-dir>/feature-design.pdf" - | grep -E '<div class=|<section class=|<span class='
```

매칭이 0건이어야 정상. 매칭이 있으면 Chapter 2 임베딩 영역이 들여쓰기 코드 블록으로 잡혀 raw HTML이 PDF에 텍스트로 출력된 상태다 → `feature-design.md` 의 Chapter 2 영역에 leading whitespace 제거 + 빈 줄 제거를 다시 적용하고 `npx md-to-pdf ...` 를 재실행한다.

### 6-5. 결과 보고

생성된 파일 경로·크기·검증 체크리스트를 사용자에게 간단히 보고한다. `feature-design.md` 는 재변환을 위해 보존한다.

---

## 완료 안내

모든 단계가 끝나면 사용자에게 실제로 생성된 파일만 체크 표시해서 안내한다:

```
📁 .feature/YYYY-MM-DD-<기능명>/
  ├── 01-analysis.md        ✅ 현황 분석
  ├── 02-design.md          ✅ 피처 설계
  ├── 03-review.md          ✅ 페르소나 리뷰 (N명)
  ├── 04-plan.md            ✅ 최종 플랜
  ├── 05-ui-demo.html       ✅ UI 데모 HTML        (생성된 경우만)
  ├── 05-ui-demo.md         ✅ UI 데모 마크다운    (생성된 경우만)
  ├── feature-design.md     ✅ PDF 빌드용 통합 md  (생성된 경우만)
  └── feature-design.pdf    ✅ PDF 종합 설계서     (생성된 경우만)

다음 단계:
- 플랜을 검토하고 피드백을 주세요
- UI 데모만 나중에 추가하려면: /feature-review <기능명> --gate demo --demo
- PDF만 나중에 만들려면: /feature-review <기능명> --gate pdf --pdf
- 구현을 시작하려면: /feature-develop <기능 설명>
- 가벼운 구현은: /develop <기능 설명>
- 추가 리뷰 라운드가 필요하면: /feature-review <기능명> --gate review
```

---

## 참고: 이터레이션

이미 `.feature/YYYY-MM-DD-<기능명>/` 폴더가 존재하고 사용자가 같은 기능에 대해 재호출하면:

1. 기존 산출물을 읽어서 컨텍스트로 활용
2. 사용자가 지정한 단계(`--gate`)부터 재실행
3. 기존 파일을 덮어쓰기 전에 사용자에게 확인
