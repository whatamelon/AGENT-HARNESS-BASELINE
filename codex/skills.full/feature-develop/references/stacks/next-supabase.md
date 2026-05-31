# Next.js + Supabase 스택 프로파일 (feature-develop)

이 프로파일은 Next.js (App Router) + Supabase 기반 프로젝트에서 `/feature-develop` 스킬이 참조하는 스택별 상세 정보이다.

## 외부 스킬

구현 단계에서 아래 외부 스킬의 규칙도 함께 적용한다:

- **프론트엔드**: vercel-react-best-practices, shadcn-ui, tailwind-design-system, next-best-practices
- **백엔드/DB**: supabase-postgres-best-practices
- **테스트**: vitest
- **타입**: typescript-advanced-types

## 빌드·검증 명령

| 용도 | 명령 |
|------|------|
| 프로덕션 빌드 | `npm run build` |
| 린트 자동 수정 | `npm run lint:fix` |
| 단위 테스트 | `npm test` 또는 대상 파일 직접 실행 |
| 개발 서버 | `npm run dev` |
| DB 타입 재생성 | `npm run db:types` |
| DB 마이그레이션 | `npm run db:migrate` |

## 아키텍처 규칙

구현 전 반드시 아래 규칙 파일을 확인하고 준수한다:

| 규칙 파일 | 내용 |
|----------|------|
| `.claude/rules/core/architecture-essentials.md` | FSD 레이어 의존성, 모놀리식 서버 로직, 네이밍 |
| `.claude/rules/core/business-core-rules.md` | 접근 제어, 상태 흐름, 감사 로그 |
| `.claude/rules/core/db-essentials.md` | 공통 컬럼, RLS, 마이그레이션 체크리스트 |

DB 변경 시 `db-essentials.md`의 마이그레이션 워크플로우를 반드시 준수한다.

## 코드 컨벤션

| 규칙 | 상세 |
|------|------|
| 파일 크기 | 300줄 이하 — 초과 시 책임 기준으로 분리 |
| 타입 안전 | `any` 금지, `unknown`으로 받고 좁히기 |
| import | 절대 경로 (`@/...`) |
| 매직 값 | 인라인 매직 넘버·문자열 금지 |
| 스타일 | 디자인 토큰 사용, arbitrary value 금지 |

## 테스트 도구

| 도구 | 용도 |
|------|------|
| Vitest | 단위/통합 테스트 |
| Playwright | E2E 테스트, UI 검증 |

- 단위 테스트 파일: 대상 함수 옆에 `.test.ts`
- E2E 테스트: Playwright MCP 사용 (클린 세션, 쿠키 축적 없음)

## 파일 구조

| 패턴 | 위치 |
|------|------|
| Server Actions | `features/*/api/actions.ts` |
| 쿼리 함수 | `entities/*/api/queries.ts` |
| Route Handlers | `app/api/**/route.ts` |
| 컴포넌트 | `features/*/ui/`, `entities/*/ui/`, `shared/ui/` |
| 상태 관리 | `features/*/model/`, `entities/*/model/` (Zustand) |
