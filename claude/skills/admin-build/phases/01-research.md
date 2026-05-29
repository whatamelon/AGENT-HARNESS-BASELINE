# Phase 01 — Research

intake 기반으로 SSOT section + 기존 repo 자산 식별.

## Step 1 — SSOT section 자동 매핑

```bash
# manifest.task_router 가 정본
sections = manifest.task_router[task_kind]
# always-load 3 + mapped sections + a11y/security cross-cut
```

`admin-build attest --task <kind>` 실행 시 자동.

## Step 2 — repo inspection

```bash
- package.json, framework, routing, UI lib
- 기존 components/admin/ 디렉토리
- tsconfig.json, tailwind.config.{js,ts}, components.json
- supabase/migrations/ (또는 prisma/schema.prisma)
- 기존 audit_logs, RLS policy, auth helper
```

## Step 3 — gap analysis

기존 자산 vs SSOT 요구 비교:
- 누락 admin foundation component (AdminShell/PageHeader/DataTable/PermissionGate 등)
- 누락 state component (LoadingState/EmptyState/ErrorState/ForbiddenState)
- 누락 audit_logs schema (또는 trigger)
- 누락 RLS policy

산출물: `.admin-build/runs/<ts>/gap-analysis.md`.

## Step 4 — Local override 검토

repo `admin/admin-design/local.md` 존재 시 로드. Tier 2 룰 (additive only). Tier 0 완화 시도 키워드 sweep:
- "다크모드 허용/켜기"
- "loading state 생략"
- "primary tint card"
- "AG Grid Enterprise 무조건"

발견 시 즉시 fail + 사유 보고.
