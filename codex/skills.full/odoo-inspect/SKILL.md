---
name: odoo-inspect
description: Guarded shared Claude Code/Codex skill for odoo-inspect; requires explicit approval before sensitive reads, writes, credentials, or external side effects.
---

# odoo-inspect — Odoo 모델 스키마·메타데이터 탐색
## Codex high-risk guardrails

- Do not execute database mutations, Odoo write methods, credential reads, secret retrieval, `.env` writes, or external side effects unless the user explicitly approves the exact operation in the current conversation.
- Prefer read-only inspection and application/API-level debugging before direct database or Odoo access.
- Never print secrets, tokens, passwords, connection strings, private customer data, or raw sensitive records. Redact by default.
- Before any write: state target system, command/method/query, expected blast radius, backup/rollback plan, and verification command.
- Flag machine-specific paths, project-specific env names, and company-specific service assumptions as portability risks.


읽기 전용. Odoo 모델의 필드, 권한, 메타 정보를 조회한다.

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

jq 대신 공유 스크립트로 파싱한다. 응답을 먼저 파일로 저장 후 실행:

| 스크립트 | 용도 |
|---------|------|
| `.claude/skills/_shared/odoo-fields.mjs` | `fields_get` 응답 → 정렬된 필드 테이블 |
| `.claude/skills/_shared/odoo-records.mjs` | `search_read` / `read` 응답 → 레코드 목록 |

```bash
# 패턴: curl 응답 저장 → 파싱
curl ... -o .claude/tmp/odoo.json \
  && node .claude/skills/_shared/odoo-fields.mjs .claude/tmp/odoo.json

# records 조회 시 --limit N 옵션 사용 가능
node .claude/skills/_shared/odoo-records.mjs .claude/tmp/odoo.json --limit 5
```

---

## 작업별 curl 템플릿

### 1. 모델 필드 목록 조회

```bash
curl -s -X POST "{ODOO_URL}/json/2/{model}/fields_get" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "attributes": ["string", "type", "required", "readonly", "relation", "selection", "help", "store"]
  }' -o .claude/tmp/odoo.json \
  && node .claude/skills/_shared/odoo-fields.mjs .claude/tmp/odoo.json
```

자주 쓰는 `attributes` 값:
- `string`: 사람이 읽을 수 있는 레이블
- `type`: 필드 타입 (char, integer, many2one, one2many, selection 등)
- `required`: 필수 여부
- `readonly`: 읽기 전용 여부
- `relation`: many2one/one2many 관계 모델명
- `selection`: selection 타입의 [값, 레이블] 배열
- `help`: 툴팁 설명
- `store`: DB에 저장 여부 (false면 computed field)

### 2. 특정 필드 상세 정보

```bash
curl -s -X POST "{ODOO_URL}/json/2/ir.model.fields/search_read" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": [["model", "=", "{model}"], ["name", "=", "{field_name}"]],
    "fields": ["name", "field_description", "ttype", "relation", "domain", "required", "readonly", "help", "selection"]
  }' -o .claude/tmp/odoo.json \
  && node .claude/skills/_shared/odoo-records.mjs .claude/tmp/odoo.json
```

### 3. 모델 존재 확인

```bash
curl -s -X POST "{ODOO_URL}/json/2/ir.model/search_read" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": [["model", "=", "{model}"]],
    "fields": ["name", "model", "info", "transient"]
  }' -o .claude/tmp/odoo.json \
  && node .claude/skills/_shared/odoo-records.mjs .claude/tmp/odoo.json
```

### 4. 모듈 설치 여부 확인

```bash
curl -s -X POST "{ODOO_URL}/json/2/ir.module.module/search_read" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": [["name", "like", "{module_name}"]],
    "fields": ["name", "shortdesc", "state", "installed_version"],
    "order": "name asc"
  }' -o .claude/tmp/odoo.json \
  && node .claude/skills/_shared/odoo-records.mjs .claude/tmp/odoo.json
```

state 값: `installed`, `uninstalled`, `to upgrade`, `to remove`

### 5. 레코드 수 확인

```bash
curl -s -X POST "{ODOO_URL}/json/2/{model}/search_count" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": []
  }' -o .claude/tmp/odoo.json \
  && node .claude/skills/_shared/odoo-records.mjs .claude/tmp/odoo.json
```

### 6. 접근 권한 확인

```bash
curl -s -X POST "{ODOO_URL}/json/2/ir.model.access/search_read" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": [["model_id.model", "=", "{model}"]],
    "fields": ["name", "group_id", "perm_read", "perm_write", "perm_create", "perm_unlink"]
  }' -o .claude/tmp/odoo.json \
  && node .claude/skills/_shared/odoo-records.mjs .claude/tmp/odoo.json
```

### 7. Selection 필드 값 목록

fields_get 결과에서 `[computed]` 없이 selection 타입 필드만 출력에서 식별 가능:

```bash
curl -s -X POST "{ODOO_URL}/json/2/{model}/fields_get" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "attributes": ["string", "type", "selection"]
  }' -o .claude/tmp/odoo.json \
  && node .claude/skills/_shared/odoo-fields.mjs .claude/tmp/odoo.json
```

출력에서 `selection` 타입 행만 확인 (선택지는 `[val1|val2|...]` 형식으로 표시됨).

### 8. 자동화 액션 확인

```bash
curl -s -X POST "{ODOO_URL}/json/2/base.automation/search_read" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": [["model_id.model", "=", "{model}"]],
    "fields": ["name", "trigger", "active", "action_server_ids"]
  }' -o .claude/tmp/odoo.json \
  && node .claude/skills/_shared/odoo-records.mjs .claude/tmp/odoo.json
```

---

## 주요 메타 모델 참조

| 모델 | 용도 |
|------|------|
| `ir.model` | 등록된 모든 모델 목록 |
| `ir.model.fields` | 모든 필드 상세 정보 |
| `ir.model.access` | 그룹별 CRUD 권한 |
| `ir.module.module` | 설치된 모듈 목록 |
| `base.automation` | 자동화 액션 (트리거) |
| `ir.rule` | 레코드 접근 규칙 |
| `ir.actions.act_window` | 메뉴에 연결된 액션 |

---

## 결과 해석 가이드

### 필드 타입 의미

| type | 설명 |
|------|------|
| `char` | 문자열 (varchar) |
| `text` | 긴 문자열 |
| `integer` | 정수 |
| `float` | 부동소수점 |
| `monetary` | 통화 금액 (`currency_id` 필드 연동) |
| `date` | 날짜 (YYYY-MM-DD) |
| `datetime` | 날짜+시간 (UTC) |
| `boolean` | 참/거짓 |
| `selection` | 고정 목록 (출력의 `[val1|val2]` 확인) |
| `many2one` | 외래키 → 출력의 `-> model.name` 확인 |
| `one2many` | 역방향 관계 (store=false → `[computed]`) |
| `many2many` | 다대다 관계 |
| `binary` | 파일/이미지 |
| `html` | HTML 컨텐츠 |

### relation 모델 follow

many2one 출력의 `-> res.partner` 형식이 보이면, 해당 모델에 동일하게 fields_get 적용.

예: `account.move`의 `partner_id -> res.partner` → `res.partner` fields_get 추가 실행
