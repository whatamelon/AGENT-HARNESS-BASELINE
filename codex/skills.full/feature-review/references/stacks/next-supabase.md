# Next.js + Supabase 스택 프로파일 (feature-review)

이 프로파일은 Next.js (App Router) + Supabase 기반 프로젝트에서 `/feature-review` 스킬이 참조하는 스택별 상세 정보이다.

## 외부 스킬

기획 단계에서 아래 외부 스킬의 규칙도 함께 적용한다:

- **UI/UX 설계 검토**: web-design-guidelines, frontend-design
- **프론트엔드 패턴**: next-best-practices, vercel-composition-patterns
- **DB 설계 검토**: supabase-postgres-best-practices

## 아키텍처 패턴

### FSD 7-레이어 (Feature-Sliced Design)

```
src/
├── app/        # App — 초기화, 프로바이더, 라우팅
├── pages/      # Pages — 라우트별 페이지 조합 (로직 없음)
├── widgets/    # Widgets — 독립적 UI 블록 (헤더, 사이드바)
├── features/   # Features — 사용자 기능 (필터, 생성, 승인)
├── entities/   # Entities — 비즈니스 도메인 모델
└── shared/     # Shared — UI Kit, API Client, Utils
```

**핵심 규칙:**
- **단방향 의존성**: App → Pages → Widgets → Features → Entities → Shared (상위 → 하위만)
- **같은 레이어 간 import 금지**
- **Public API**: 모든 슬라이스는 `index.ts`를 통해서만 외부 노출
- 슬라이스 세그먼트: `ui/`, `api/`, `model/`, `lib/`, `index.ts`

### 서버 로직 — 모놀리식 Next.js

| 패턴 | 위치 | 사용 조건 |
|------|------|-----------|
| Server Actions | `features/*/api/actions.ts`, `entities/*/api/queries.ts` | 기본 (CRUD, 비즈니스 로직, 조회) |
| Route Handlers | `app/api/**/route.ts` | 웹훅, 외부 연동, 스트리밍 등 Actions로 불가능한 경우만 |

## 규칙 파일 참조

현황 분석(Step 1) 및 설계(Step 2)에서 아래 규칙 파일을 확인하고, 기존 코드의 준수 여부도 기록한다:

| 규칙 파일 | 내용 |
|----------|------|
| `.claude/rules/core/architecture-essentials.md` | FSD 레이어 의존성, 모놀리식 서버 로직, 네이밍 |
| `.claude/rules/core/business-core-rules.md` | 비즈니스 규칙, 접근 제어, 상태 흐름 |
| `.claude/rules/core/db-essentials.md` | DB 설계, RLS, 마이그레이션 체크리스트 |

## 코드 컨벤션

| 대상 | 규칙 |
|------|------|
| 파일명 | `kebab-case` |
| 컴포넌트 | `PascalCase` |
| 함수/변수 | `camelCase` |
| 상수 | `UPPER_SNAKE_CASE` |
| import | 절대 경로 (`@/...`) |
| 파일 크기 | 300줄 이하, 초과 시 책임 기준 분리 |
| 타입 | `any` 금지, `unknown`으로 받고 좁히기 |
| 스타일 | 디자인 토큰 사용, arbitrary value 금지 |
