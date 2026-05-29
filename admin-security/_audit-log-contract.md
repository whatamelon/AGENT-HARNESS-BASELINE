---
slug: audit-log-contract
tier: 0   # tier 0 — non-negotiable security
description: 모든 admin CUD 가 audit_logs 에 적재될 때 만족해야 하는 계약.
---

# Audit Log Contract

## 의무 적용 범위

다음 action 은 반드시 `audit_logs` insert:

- create (모든 admin domain)
- update
- delete (soft 또는 hard)
- approve / reject
- refund / cancel
- invite / deactivate (user/role)
- settings.manage
- 권한 변경 (role/permission update)
- export (대용량 데이터 추출 시)

## audit_logs schema (minimum)

```sql
CREATE TABLE audit_logs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at  timestamptz NOT NULL DEFAULT now(),
  user_id     uuid REFERENCES auth.users(id),
  action      text NOT NULL,                  -- 'create' | 'update' | 'delete' | ...
  table_name  text NOT NULL,
  record_id   uuid,
  before_data jsonb,
  after_data  jsonb,
  metadata    jsonb,                          -- ip, user_agent, request_id, org_id
  organization_id uuid REFERENCES organizations(id)
);

CREATE INDEX idx_audit_logs_user ON audit_logs (user_id, created_at DESC);
CREATE INDEX idx_audit_logs_record ON audit_logs (table_name, record_id);
CREATE INDEX idx_audit_logs_org ON audit_logs (organization_id, created_at DESC);
```

## 구현 방식 (택1)

1. **DB trigger** — 가장 신뢰성 높음. Supabase 라면 `BEFORE INSERT/UPDATE/DELETE` trigger 로 audit_logs insert.
2. **Server-side wrapper** — server action / API route 안에서 mutation 후 audit insert. transaction 안에서.
3. **outbox + worker** — audit_outbox 에 적재 후 worker 가 audit_logs 로 영구화. 부하 큰 경우.

## verifier 검증

L3 runtime fixture (owner/ops 4종) 로 다음 시퀀스 실행:

```
1. INSERT /api/<domain>          → expect audit_logs count +1
2. PATCH /api/<domain>/<id>      → expect audit_logs count +1 + before_data 기록
3. DELETE /api/<domain>/<id>     → expect audit_logs count +1 + after_data NULL
4. forbidden fixture 로 동일 → expect audit_logs unchanged (server 가 403)
```

## 금지

- audit_logs 를 **client 에서 직접 insert** — 무조건 server 측에서만.
- audit_logs **soft delete or update** — append-only. (정정 필요 시 새 row.)
- audit_logs 에 **민감 필드 평문 적재** — password/token/ssn 등은 hashed 또는 redacted.
- audit_logs RLS 를 **service_role only** 로만 두지 않음 — admin/owner read 도 필요. (단, write 는 service_role 만.)
