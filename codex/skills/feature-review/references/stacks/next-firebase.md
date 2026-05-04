# Next.js + Firebase 스택 프로파일 (feature-review)

이 프로파일은 Next.js (App Router) + Firebase 기반 프로젝트에서 `/feature-review` 스킬이 참조하는 스택별 상세 정보이다.

## 외부 스킬

기획 단계에서 아래 외부 스킬의 규칙도 함께 적용한다:

- **UI/UX 설계 검토**: web-design-guidelines, frontend-design
- **프론트엔드 패턴**: next-best-practices, vercel-composition-patterns

## 아키텍처 패턴

### 3-레이어 구조

```
Presentation → Hooks/Services → Firebase
```

```
src/
├── app/          # Presentation — UI 렌더링, 라우팅
├── components/   # Presentation — 재사용 UI 컴포넌트
├── hooks/        # Hooks — 데이터 페칭(React Query), 상태 관리
├── services/     # Services — Firestore CRUD, 비즈니스 로직
├── contexts/     # Context — AuthContext 등 중앙 상태
├── lib/          # Lib — Firebase 초기화, 유틸리티, 상수
├── types/        # Types — 공유 타입 정의
└── locales/      # i18n 번역 파일
functions/
└── src/          # Cloud Functions — 서버사이드 로직 (이메일, OCR, 웹훅)
```

**핵심 규칙:**
- **Firestore 접근은 반드시 `src/services/` 경유** — 컴포넌트에서 직접 호출 금지
- **Cloud Functions는 클라이언트가 직접 실행 불가한 작업만** (이메일 발송, OCR, 웹훅)
- **인증 상태는 `AuthContext`에서 중앙 관리**
- **역할 기반 접근 제어**: 관리자 / 콘텐츠 생성자 / 바이럴 마케터

### 서버 로직 — Cloud Functions 분리 모델

| 패턴 | 위치 | 사용 조건 |
|------|------|-----------|
| Firestore 서비스 | `src/services/*.ts` | 클라이언트 CRUD, 비즈니스 로직 |
| React Query 훅 | `src/hooks/use*.ts` | 데이터 페칭, 캐싱, 실시간 구독 |
| Cloud Functions | `functions/src/` | 서버 전용 작업 (외부 API, 스케줄, 트리거) |
| API Routes | `src/app/api/**/route.ts` | Next.js 서버사이드 엔드포인트 |

## 규칙 파일 참조

현황 분석(Step 1) 및 설계(Step 2)에서 아래 규칙 파일을 확인하고, 기존 코드의 준수 여부도 기록한다:

| 규칙 파일 | 내용 |
|----------|------|
| `.claude/rules/core/architecture.md` | 3-레이어 의존성, Firestore 접근 경로, Cloud Functions 역할 |
| `.claude/rules/core/conventions.md` | 네이밍, 파일 구조(300줄 이하), TypeScript, import 규칙 |
| `.claude/rules/core/quality.md` | 에러 처리, 유효성 검증, 보안 |

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
| 불리언 | `is`, `has`, `can`, `should` 접두사 |
