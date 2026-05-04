---
name: db-query
description: Supabase MCP로 DB를 직접 조회 (읽기 전용, 디버깅/분석 목적)
---

# DB 직접 조회
## Codex high-risk guardrails

- Do not execute database mutations, Odoo write methods, credential reads, secret retrieval, `.env` writes, or external side effects unless the user explicitly approves the exact operation in the current conversation.
- Prefer read-only inspection and application/API-level debugging before direct database or Odoo access.
- Never print secrets, tokens, passwords, connection strings, private customer data, or raw sensitive records. Redact by default.
- Before any write: state target system, command/method/query, expected blast radius, backup/rollback plan, and verification command.
- Flag machine-specific paths, project-specific env names, and company-specific service assumptions as portability risks.


> **⚠ 사용 전 필수 확인**: 기존 API 라우트로 조회 가능한 경우 이 스킬을 사용하지 않는다.
> `apps/web/src/app/api/` 하위 라우트를 먼저 확인하고, API로 해결 불가한 경우에만 진행한다.

## 허용 용도

- API가 노출하지 않는 크로스 테이블 분석 (집계, JOIN)
- 프로덕션 버그 원인 파악을 위한 데이터 상태 확인
- 마이그레이션 전/후 데이터 검증
- 성능 이슈 분석

## 절차

### 1. API 대안 확인
요청 데이터가 기존 API 라우트로 조회 가능한지 검토한다. 가능하면 API 사용을 권고하고 중단.

### 2. Prisma 스키마로 테이블/컬럼 확인

SQL 작성 전 반드시 `packages/database/prisma/schema.prisma`를 참조한다.

**확인 항목**
- 실제 테이블명: `@@map("실제_테이블명")` 값 사용
- 실제 컬럼명: `@map("실제_컬럼명")` 값 사용 (없으면 camelCase → snake_case 변환)
- 스키마: `@@schema("som")` 또는 `@@schema("public")`
- 관계(FK): `@relation` 확인 후 JOIN 조건 구성

**스키마별 주요 테이블 요약**

| Prisma 모델 | 실제 테이블 | 스키마 |
|---|---|---|
| PlatformUser | platform_users | som |
| Employee | platform_employees | som |
| Organization | platform_organizations | som |
| Department | platform_departments | som |
| Team | platform_teams | som |
| Group | platform_groups | som |
| Company | platform_companies | som |
| OrgUnit | platform_org_units | som |
| Role | platform_roles | som |
| Permission | platform_permissions | som |
| UserRole | platform_user_roles | som |
| Module | platform_modules | som |
| MenuItem | platform_menu_items | som |
| CommonCodeGroup | platform_common_code_groups | som |
| CommonCode | platform_common_codes | som |
| CalendarEvent | calendar_events | som |
| KakaoworkChannel | kakaowork_channels | som |
| OdooCompanyMapping | odoo_company_mappings | som |
| IntercompanyTransaction | intercompany_transactions | som |
| User (레거시) | users | public |
| MasterData (레거시) | master_data | public |

**SQL 작성 규칙**
```sql
-- ✅ 올바른 예: 스키마 접두사 + 실제 테이블명 + 실제 컬럼명
SELECT u.user_id, u.user_name, u.email
FROM som.platform_users u
WHERE u.is_active = true
LIMIT 100;

-- ❌ 잘못된 예: Prisma 모델명 사용
SELECT * FROM PlatformUser;

-- ❌ 잘못된 예: camelCase 컬럼명 사용
SELECT userName FROM platform_users;
```

### 3. 쿼리 작성 원칙
- `SELECT`만 사용 (INSERT/UPDATE/DELETE 절대 금지)
- 필요한 컬럼만 명시적으로 선택 — `SELECT *` 금지
- `LIMIT` 항상 포함 (기본 100, 최대 500)
- 민감 컬럼 제외: `password_hash`, `auth_user_id` 등

### 4. 실행
`mcp__supabase__execute_sql`로 쿼리 실행.

### 5. 결과 보고
조회 목적, SQL, 결과 요약을 명시적으로 출력. 이상 데이터 발견 시 원인 분석 및 권고 사항 제시.

## 금지 사항
- `SELECT *` 사용 금지
- `LIMIT` 없는 조회 금지
- DML/DDL 실행 금지
- `auth.users` 등 Supabase 내부 테이블 직접 조회 자제
- Prisma 모델명/camelCase 컬럼명을 SQL에 그대로 사용 금지
