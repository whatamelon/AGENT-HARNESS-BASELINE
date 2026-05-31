---
name: odoo-query
description: Guarded shared Claude Code/Codex skill for odoo-query; requires explicit approval before sensitive reads, writes, credentials, or external side effects.
---

# odoo-query — Odoo 실제 데이터 조회
## Codex high-risk guardrails

- Do not execute database mutations, Odoo write methods, credential reads, secret retrieval, `.env` writes, or external side effects unless the user explicitly approves the exact operation in the current conversation.
- Prefer read-only inspection and application/API-level debugging before direct database or Odoo access.
- Never print secrets, tokens, passwords, connection strings, private customer data, or raw sensitive records. Redact by default.
- Before any write: state target system, command/method/query, expected blast radius, backup/rollback plan, and verification command.
- Flag machine-specific paths, project-specific env names, and company-specific service assumptions as portability risks.


읽기 전용. 운영/개발 DB의 실제 레코드를 조회한다.

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

```bash
# 기본 패턴
curl ... -o .claude/tmp/odoo.json \
  && node .claude/skills/_shared/odoo-records.mjs .claude/tmp/odoo.json

# 건수만 확인 (search_count) — 동일 스크립트, 숫자 자동 감지
node .claude/skills/_shared/odoo-records.mjs .claude/tmp/odoo.json

# 첫 N건만 출력
node .claude/skills/_shared/odoo-records.mjs .claude/tmp/odoo.json --limit 5
```

---

## 작업별 curl 템플릿

### 1. 도메인 필터 조회 (search_read)

```bash
curl -s -X POST "{ODOO_URL}/json/2/{model}/search_read" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": [],
    "fields": ["id", "name"],
    "limit": 10,
    "offset": 0,
    "order": "id desc"
  }' -o .claude/tmp/odoo.json \
  && node .claude/skills/_shared/odoo-records.mjs .claude/tmp/odoo.json
```

**파라미터 가이드**:
- `domain`: 필터 배열. 빈 배열 `[]` = 전체
- `fields`: 조회 필드 목록. `[]` = 전체 (성능 주의, 필요한 필드만 지정 권장)
- `limit`: 기본 80, 전체 조회 시 명시적으로 크게 설정 (예: 1000)
- `offset`: 페이지네이션 시작 위치
- `order`: 정렬 (`"id desc"`, `"name asc"`, `"write_date desc"`)

### 2. ID로 단건 조회 (read)

```bash
curl -s -X POST "{ODOO_URL}/json/2/{model}/read" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "ids": [1, 2, 3],
    "fields": ["id", "name"]
  }' -o .claude/tmp/odoo.json \
  && node .claude/skills/_shared/odoo-records.mjs .claude/tmp/odoo.json
```

### 3. 그룹별 집계 (read_group)

```bash
curl -s -X POST "{ODOO_URL}/json/2/{model}/read_group" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": [],
    "fields": ["{group_field}", "{agg_field}:sum"],
    "groupby": ["{group_field}"],
    "orderby": "{group_field} asc"
  }' -o .claude/tmp/odoo.json \
  && node .claude/skills/_shared/odoo-records.mjs .claude/tmp/odoo.json
```

집계 함수: `:sum`, `:avg`, `:min`, `:max`, `:count`

### 4. ID 목록만 조회 (search)

```bash
curl -s -X POST "{ODOO_URL}/json/2/{model}/search" \
  -H "Authorization: Bearer {ODOO_API_KEY}" \
  -H "X-Odoo-Database: {ODOO_DB}" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": [["active", "=", true]],
    "limit": 100,
    "order": "id desc"
  }' -o .claude/tmp/odoo.json \
  && node .claude/skills/_shared/odoo-records.mjs .claude/tmp/odoo.json
```

---

## 자주 쓰는 모델

| 모델 | 설명 |
|------|------|
| `res.partner` | 거래처/고객/공급업체 |
| `res.company` | 법인 |
| `res.users` | 사용자 |
| `account.move` | 전표 (인보이스, 빌, 분개장) |
| `account.move.line` | 전표 라인 |
| `account.account` | 계정과목 |
| `sale.order` | 수주 |
| `sale.order.line` | 수주 라인 |
| `purchase.order` | 발주 |
| `purchase.order.line` | 발주 라인 |
| `stock.picking` | 재고 이동 (입고/출고) |
| `stock.move` | 재고 이동 라인 |
| `hr.employee` | 직원 |
| `hr.leave` | 휴가 신청 |
| `product.product` | 제품 (variant) |
| `product.template` | 제품 템플릿 |
| `mrp.production` | 생산 오더 |

---

## Domain 문법 참조

### 기본 연산자

```json
[["field", "=", value]]        // 같음
[["field", "!=", value]]       // 다름
[["field", ">", value]]        // 초과
[["field", ">=", value]]       // 이상
[["field", "<", value]]        // 미만
[["field", "<=", value]]       // 이하
[["field", "in", [1, 2, 3]]]   // 포함
[["field", "not in", [1, 2]]]  // 미포함
[["field", "like", "text"]]    // 부분 일치 (대소문자 구분)
[["field", "ilike", "text"]]   // 부분 일치 (대소문자 무시)
[["field", "=", false]]        // NULL 또는 false
[["field", "!=", false]]       // NOT NULL
```

### 논리 연산자

```json
// AND (기본 - 배열 내 여러 조건은 AND)
[["a", "=", 1], ["b", "=", 2]]

// OR
["|", ["a", "=", 1], ["b", "=", 2]]

// NOT
["!", ["field", "=", value]]

// 복합
["|", ["a", "=", 1], "&", ["b", "=", 2], ["c", "=", 3]]
```

### 관계 필드 탐색

```json
// many2one 관계 필드
[["partner_id.name", "ilike", "홍길동"]]
[["company_id.country_id.code", "=", "KR"]]

// many2many 관계
[["category_ids", "in", [1, 2, 3]]]
```

---

## 자주 쓰는 도메인 패턴

```json
// 활성 레코드만
[["active", "=", true]]

// 특정 회사 소속
[["company_id", "=", 1]]

// 날짜 범위
[["date", ">=", "2025-01-01"], ["date", "<=", "2025-12-31"]]

// 상태 필터
[["state", "in", ["draft", "posted"]]]

// 고객(거래처)만
[["customer_rank", ">", 0]]

// 공급업체만
[["supplier_rank", ">", 0]]

// 특정 사용자 관련
[["user_id", "=", 2]]

// 최근 수정
[["write_date", ">=", "2025-01-01 00:00:00"]]
```

---

## 주의사항

- `fields: []` 로 전체 조회 시 성능 저하 가능 — 필요한 필드만 명시
- `limit` 미지정 시 기본값 80 적용 — 전체 데이터 필요하면 명시적 설정
- many2one 필드 반환값은 `[id, "display_name"]` 배열 형태 (스크립트가 `[id] name`으로 포맷)
- 날짜/시간은 UTC 기준으로 저장됨 (한국 시간 = UTC+9)
