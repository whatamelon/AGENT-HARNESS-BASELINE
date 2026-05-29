-- admin-security/_rls-tests.sql — Supabase RLS 의무 assertion
-- admin-build 의 L3 verifier 가 fixture 4종 (owner/ops/viewer/forbidden) JWT 로 SET ROLE 후 본 쿼리 실행.
-- 모든 assertion 통과 시 RBAC 게이트 PASS.

-- =============================================================
-- 1. Service role 노출 금지
-- =============================================================
-- 브라우저 bundle 에 service_role key 가 들어가면 RLS 우회 가능 → 빌드 fail.
-- (이 검증은 _secret-leak.yaml 의 L1 grep 가 담당. 본 파일은 DB 측 검증만.)

-- =============================================================
-- 2. exposed table 마다 RLS enable 검증
-- =============================================================
-- expected: 모든 admin-facing table 에서 rowsecurity = true
SELECT
  tablename,
  rowsecurity AS rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename NOT IN ('schema_migrations', 'audit_outbox')
  AND rowsecurity = false;
-- assertion: 결과 0 row

-- =============================================================
-- 3. cross-org SELECT deny (project-specific — bbakcar-web 기준 예시)
-- =============================================================
-- fixture: ops_user (org_id = 'org-A')
-- query: SELECT * FROM vehicles WHERE organization_id != 'org-A'
-- expected: 0 row (RLS deny)
--
-- 본 파일은 fixture 마다 다음 패턴 자동 생성:
-- SET LOCAL ROLE authenticated;
-- SET LOCAL request.jwt.claims = '{"sub":"<fixture-sub>","org_id":"<fixture-org>","role":"<fixture-role>"}';
-- SELECT count(*) FROM <table> WHERE organization_id != '<fixture-org>';
-- ASSERT count = 0

-- =============================================================
-- 4. forbidden fixture: 모든 protected table SELECT 0
-- =============================================================
-- fixture: forbidden_user (no org membership)
-- expected: SELECT * FROM <every_protected_table> → 0 row
--
-- pattern (verifier 가 모든 RLS 활성 테이블에 대해 generate):
-- SET LOCAL request.jwt.claims = '{"sub":"forbidden-user","role":"authenticated"}';
-- SELECT count(*) FROM vehicles;       -- expect 0
-- SELECT count(*) FROM test_drives;    -- expect 0
-- SELECT count(*) FROM consultations;  -- expect 0
-- ...

-- =============================================================
-- 5. policy 네이밍 컨벤션
-- =============================================================
-- 정책 이름: {table}_{role}_{action}
-- 예: vehicles_owner_select, vehicles_authenticated_select, vehicles_admin_update
SELECT
  schemaname,
  tablename,
  policyname,
  cmd,
  CASE
    WHEN policyname ~ '^[a-z_]+_[a-z_]+_[a-z_]+$' THEN 'ok'
    ELSE 'naming_violation'
  END AS naming_check
FROM pg_policies
WHERE schemaname = 'public'
  AND policyname !~ '^[a-z_]+_[a-z_]+_[a-z_]+$';
-- assertion: 결과 0 row (모든 정책 이름이 컨벤션 충족)

-- =============================================================
-- 6. service_role 정책은 명시적
-- =============================================================
-- service_role 우회 정책은 narrow scope + 명시적 명명 필수.
SELECT
  tablename,
  policyname,
  roles
FROM pg_policies
WHERE 'service_role' = ANY(roles)
  AND tablename NOT IN ('audit_outbox', 'background_jobs');
-- assertion: service_role 정책은 system 테이블 에만. 그 외 발견 시 review.

-- =============================================================
-- 7. audit_logs INSERT trigger 존재
-- =============================================================
-- 모든 CUD 가 audit_logs 에 insert 되도록 trigger 존재 검증.
SELECT
  c.relname AS table_name,
  t.tgname AS trigger_name
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE NOT t.tgisinternal
  AND t.tgname ILIKE '%audit%'
ORDER BY c.relname;
-- assertion: 모든 protected_tables 에 audit trigger 1개 이상
