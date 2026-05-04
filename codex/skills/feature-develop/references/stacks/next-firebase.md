# Next.js + Firebase 스택 프로파일 (feature-develop)

이 프로파일은 Next.js (App Router) + Firebase 기반 프로젝트에서 `/feature-develop` 스킬이 참조하는 스택별 상세 정보이다.

## 외부 스킬

구현 단계에서 아래 외부 스킬의 규칙도 함께 적용한다:

- **프론트엔드**: next-best-practices, vercel-composition-patterns
- **테스트**: vitest

## 빌드·검증 명령

| 용도 | 명령 |
|------|------|
| 프로덕션 빌드 | `npm run build` |
| 린트 | `npm run lint` |
| 단위 테스트 | `npm run test` 또는 `vitest run <파일>` |
| 개발 서버 | `npm run dev` (Next.js + Firebase Emulator 동시 실행) |

## 아키텍처 규칙

구현 전 반드시 아래 규칙 파일을 확인하고 준수한다:

| 규칙 파일 | 내용 |
|----------|------|
| `.claude/rules/core/architecture.md` | 3-레이어 의존성, Firestore 접근 경로, Cloud Functions 역할 |
| `.claude/rules/core/conventions.md` | 네이밍, 파일 구조(300줄 이하), TypeScript, import 규칙 |
| `.claude/rules/core/quality.md` | 에러 처리, 유효성 검증, 보안 |

**레이어 금지 사항:**

| 레이어 | 위치 | 금지 |
|--------|------|------|
| Presentation | `src/app/`, `src/components/` | Firestore 직접 접근 |
| Hooks | `src/hooks/` | 비즈니스 로직 |
| Services | `src/services/` | UI 코드 |
| Cloud Functions | `functions/` | 클라이언트 상태 |

## 코드 컨벤션

| 규칙 | 상세 |
|------|------|
| 파일 크기 | 300줄 이하 — 초과 시 책임 기준으로 분리 |
| 타입 안전 | `any` 금지, `unknown`으로 받고 좁히기 |
| import | 절대 경로 (`@/...`) |
| 매직 값 | 인라인 매직 넘버·문자열 금지 |
| 불리언 | `is`, `has`, `can`, `should` 접두사 |

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
| Firestore 서비스 | `src/services/*Service.ts` |
| React Query 훅 | `src/hooks/use*.ts` |
| Cloud Functions | `functions/src/` |
| API Routes | `src/app/api/**/route.ts` |
| 컴포넌트 | `src/components/` |
| 상태 관리 | `src/contexts/` (React Context) |
| Firebase 초기화 | `src/lib/firebase.ts`, `src/lib/firebase-admin.ts` |
| 유틸리티 | `src/lib/utils/` |
| 타입 정의 | `src/types/` |
