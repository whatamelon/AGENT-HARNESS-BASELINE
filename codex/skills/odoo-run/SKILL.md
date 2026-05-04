---
name: odoo-run
description: Guarded shared Claude Code/Codex skill for odoo-run; requires explicit approval before sensitive reads, writes, credentials, or external side effects.
---

# odoo-run — Odoo 임의 메서드 실행
## Codex high-risk guardrails

- Do not execute database mutations, Odoo write methods, credential reads, secret retrieval, `.env` writes, or external side effects unless the user explicitly approves the exact operation in the current conversation.
- Prefer read-only inspection and application/API-level debugging before direct database or Odoo access.
- Never print secrets, tokens, passwords, connection strings, private customer data, or raw sensitive records. Redact by default.
- Before any write: state target system, command/method/query, expected blast radius, backup/rollback plan, and verification command.
- Flag machine-specific paths, project-specific env names, and company-specific service assumptions as portability risks.


**쓰기 가능. 실행 전 반드시 사용자 승인 요청.**

## 환경변수 준비

```
Read: apps/web/.env.local
추출: ODOO_URL, ODOO_DB, ODOO_API_KEY
```

## API 기본 형식

```bash
curl -s -X POST "{ODOO_URL}/json/2/{model}/{method}" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{kwargs}'
```

## 출력 유틸리티

결과 확인 시 공유 스크립트 사용:

```bash
# 응답 저장 → 레코드 파싱
curl ... -o .claude/tmp/odoo.json \
  && node .claude/skills/_shared/odoo-records.mjs .claude/tmp/odoo.json

# true/false 등 단순 반환은 파일 내용 직접 확인
cat .claude/tmp/odoo.json
```

---

## 사용자 승인 필수 체크리스트

실행 전 다음을 사용자에게 명확히 알리고 승인 받는다:

1. **대상 DB**: `{ODOO_DB}` (운영 DB인지 확인)
2. **실행 메서드**: `{model}.{method}`
3. **영향 범위**: 영향받는 레코드 수 또는 ID 목록
4. **되돌리기 가능 여부**: 삭제/상태 전환은 복원 어려움

### 즉시 실행 가능 (승인 불필요)
- `check_access_rights`, `check_field_access_rights` — 권한 확인
- `onchange` — 필드 변경 시뮬레이션 (실제 저장 없음)
- `_get_report_values` — 보고서 데이터 미리 보기

### 반드시 승인 후 실행
- `create` — 새 레코드 생성
- `write` — 레코드 수정
- `unlink` — 레코드 삭제 (**되돌리기 불가**)
- `action_confirm`, `action_post` 등 상태 전환
- 커스텀 비즈니스 메서드

---

## 작업별 curl 템플릿

### 1. 권한 확인 (읽기 전용, 승인 불필요)

```bash
curl -s -X POST "{ODOO_URL}/json/2/{model}/check_access_rights" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "operation": "read",
    "raise_exception": false
  }' -o .claude/tmp/odoo.json && cat .claude/tmp/odoo.json
```

`operation` 값: `"read"`, `"write"`, `"create"`, `"unlink"`

### 2. onchange 시뮬레이션 (읽기 전용, 승인 불필요)

```bash
curl -s -X POST "{ODOO_URL}/json/2/{model}/onchange" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "ids": [],
    "values": {"{changed_field}": {value}},
    "field_name": ["{changed_field}"],
    "field_onchange": {"{field_to_observe}": "1"}
  }' -o .claude/tmp/odoo.json \
  && node .claude/skills/_shared/odoo-records.mjs .claude/tmp/odoo.json
```

### 3. 레코드 생성 (승인 필요)

```bash
curl -s -X POST "{ODOO_URL}/json/2/{model}/create" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "vals": {
      "field1": "value1",
      "field2": value2
    }
  }' -o .claude/tmp/odoo.json && cat .claude/tmp/odoo.json
```

반환값: 생성된 레코드 ID

### 4. 레코드 수정 (승인 필요)

```bash
curl -s -X POST "{ODOO_URL}/json/2/{model}/write" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "ids": [1, 2],
    "vals": {
      "field": "new_value"
    }
  }' -o .claude/tmp/odoo.json && cat .claude/tmp/odoo.json
```

반환값: `true` (성공) / 에러 객체 (실패)

### 5. 레코드 삭제 (승인 필요, 되돌리기 불가)

```bash
curl -s -X POST "{ODOO_URL}/json/2/{model}/unlink" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "ids": [1]
  }' -o .claude/tmp/odoo.json && cat .claude/tmp/odoo.json
```

### 6. 워크플로우 액션 (승인 필요)

```bash
curl -s -X POST "{ODOO_URL}/json/2/{model}/{action_method}" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "ids": [1]
  }' -o .claude/tmp/odoo.json && cat .claude/tmp/odoo.json
```

자주 쓰는 액션 메서드:
- `action_confirm` — 확인/승인 (sale.order, purchase.order 등)
- `action_post` — 전기 (account.move)
- `action_cancel` — 취소
- `action_draft` — 초안으로 되돌리기
- `action_validate` — 검증/확정

### 7. 커스텀 비즈니스 메서드 (승인 필요)

```bash
curl -s -X POST "{ODOO_URL}/json/2/{model}/{custom_method}" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "ids": [1],
    "param1": "value1"
  }' -o .claude/tmp/odoo.json \
  && node .claude/skills/_shared/odoo-records.mjs .claude/tmp/odoo.json
```

### 8. 보고서 데이터 미리 보기 (읽기 전용)

```bash
curl -s -X POST "{ODOO_URL}/json/2/report.{module}.{report_name}/_get_report_values" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "docids": [1],
    "data": {}
  }' -o .claude/tmp/odoo.json \
  && node .claude/skills/_shared/odoo-records.mjs .claude/tmp/odoo.json
```

---

## 실행 후 결과 확인

쓰기 작업 후 반드시 read로 결과 확인:

```bash
curl -s -X POST "{ODOO_URL}/json/2/{model}/read" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "ids": [{affected_id}],
    "fields": ["id", "name", "state", "write_date"]
  }' -o .claude/tmp/odoo.json \
  && node .claude/skills/_shared/odoo-records.mjs .claude/tmp/odoo.json
```

---

## 에러 응답 해석

Odoo JSON-2 API 에러 형식:

```json
{
  "error": {
    "code": 200,
    "message": "Odoo Server Error",
    "data": {
      "name": "odoo.exceptions.AccessError",
      "debug": "...",
      "message": "You are not allowed to access..."
    }
  }
}
```

주요 에러 타입:
- `AccessError` — 권한 없음
- `ValidationError` — 데이터 검증 실패
- `UserError` — 비즈니스 로직 오류
- `MissingError` — 레코드 없음 (삭제됨 또는 잘못된 ID)

---

## 금지 작업 목록

다음 작업은 어떠한 경우에도 수행 금지:

- 운영 DB에서 핵심 마스터 데이터 대량 삭제 (`unlink`)
- 회계 전기된 전표 강제 수정
- 사용자 비밀번호/권한 무단 변경
- `ir.config_parameter` 시스템 설정 임의 변경
- 모듈 강제 설치/제거
