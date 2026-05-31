---
name: db-patch
description: Supabase MCP로 DB 데이터를 직접 수정 (극히 예외적 상황, 사용자 명시 승인 필수)
---

# DB 직접 수정
## Codex high-risk guardrails

- Do not execute database mutations, Odoo write methods, credential reads, secret retrieval, `.env` writes, or external side effects unless the user explicitly approves the exact operation in the current conversation.
- Prefer read-only inspection and application/API-level debugging before direct database or Odoo access.
- Never print secrets, tokens, passwords, connection strings, private customer data, or raw sensitive records. Redact by default.
- Before any write: state target system, command/method/query, expected blast radius, backup/rollback plan, and verification command.
- Flag machine-specific paths, project-specific env names, and company-specific service assumptions as portability risks.


> **🚨 이 스킬은 최후의 수단이다.**
>
> 반드시 아래 조건을 모두 충족한 경우에만 사용한다:
> 1. 기존 API 라우트로 처리가 불가능한 상황 (API 버그, 미구현 엔드포인트)
> 2. 사용자가 명시적으로 직접 수정을 승인
> 3. 수정 대상이 단건 또는 명확히 특정된 소수의 레코드

## 허용 용도

- API 버그로 인해 특정 레코드가 잘못된 상태로 저장된 경우의 데이터 정정
- 마이그레이션 실패로 인한 데이터 복구
- 운영 긴급 상황에서 API 배포 전 임시 데이터 수정

## 절차

### 1. API 대안 최종 확인
`apps/web/src/app/api/` 하위 라우트 재확인. API로 처리 가능하면 즉시 중단하고 API 사용 권고.

### 2. Prisma 스키마로 테이블/컬럼 확인

SQL 작성 전 반드시 `packages/database/prisma/schema.prisma`를 참조한다.

**확인 항목**
- 실제 테이블명: `@@map("실제_테이블명")` 값 사용
- 실제 컬럼명: `@map("실제_컬럼명")` 값 사용 (없으면 camelCase → snake_case 변환)
- 스키마: `@@schema("som")` 또는 `@@schema("public")`
- FK 제약: `@relation` 확인 — 외래키 위반이 발생하지 않도록 수정 순서 결정
- 감사 필드: `updated_at`, `updated_id`는 반드시 함께 갱신

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
-- ✅ 올바른 예: 감사 필드 포함, WHERE 조건 명확
UPDATE som.platform_users
SET is_locked = false,
    password_fail_count = 0,
    updated_at = NOW(),
    updated_id = 'SYSTEM'
WHERE user_id = 'hong-123';

-- ❌ 잘못된 예: WHERE 없음 (전체 테이블 영향)
UPDATE som.platform_users SET is_active = false;
```

### 3. 영향 범위 파악
`mcp__supabase__execute_sql`로 SELECT 먼저 실행하여 수정 대상 확인.
영향받는 레코드 수와 현재 값을 사용자에게 보고.

### 4. 사용자 최종 승인 요청

다음 내용을 명시하고 승인을 받는다:

```
[DB 직접 수정 승인 요청]
- 테이블: som.{table_name}
- 대상 레코드: {N}건
- 현재 값: {before}
- 변경 값: {after}
- 실행 SQL: {sql}
- 사유: {reason}
```

### 5. 실행
승인 확인 후 `mcp__supabase__execute_sql`로 실행.
단건씩 실행 원칙 (배치 UPDATE는 특별한 사유 없으면 금지).

### 6. 사후 검증
SELECT로 변경 결과 확인. 관련 API 엔드포인트로 데이터 정합성 재확인.

### 7. 완료 보고
```
[DB 직접 수정 완료]
- 테이블: {table_name}
- 수정 레코드: {N}건
- 실행 SQL: {sql}
- 검증 결과: {정상/이상}
```

## 절대 금지 사항

- 사용자 승인 없이 DML 실행
- `WHERE` 없는 UPDATE/DELETE (전체 테이블 영향)
- DDL 실행 — 스키마 변경은 `supabase/migrations/`에 파일 생성
- `auth.users` 테이블 직접 수정 — Supabase Auth API 사용
- `password_hash`, `auth_user_id` 등 보안 필드 직접 수정
- 외래키 제약을 우회하는 수정
- `updated_at` / `updated_id` 감사 필드 누락
- Prisma 모델명/camelCase 컬럼명을 SQL에 그대로 사용 금지
