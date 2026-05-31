# Schema/Auth/Query — 추측 금지, 실 데이터 우선

## 핵심 규칙

> **신규 코드가 기존 codebase 의 schema/RLS/사용 패턴에 의존할 때, 추측으로 짜지 말고 실 데이터를 먼저 확인한다. 특히 auth/session/permission/query 영역.**

빡차 2026-05-28 사고: `bbakcar-admin` 의 `getSession()` 가 4번 실패. 매번 동일 근본 원인 = `bbakcar-web` 의 실 schema/패턴 확인 없이 추측 작성. 사용자 "여전한데?" 3번 반복 후에야 console.log + 외부 curl 로 진짜 데이터 봄.

## 4종 의무 확인 (auth/session/query 코드 작성 전)

### 1. 실 schema 확인

신규 query 작성 전:

```bash
# 컬럼 명 확인 — generated types 또는 실 row
grep -A 20 "^export interface ${TABLE}" <repo>/src/types/database.types.ts
# 또는 service_role 로 select * 1 row
curl -s -H "apikey: $SECRET" -H "Authorization: Bearer $SECRET" \
  "$SUPABASE_URL/rest/v1/${TABLE}?select=*&limit=1" | python3 -m json.tool
```

**금지**: column 명 (`created_at`, `is_admin`, `role`) 외워서 select. 실 schema 가 `joined_at`, `updated_at`, `is_active` 일 수 있음.

### 2. 실 RLS 정책 확인

```bash
# 본인 row 조회 가능 여부 publishable key 로 외부 curl 테스트
PUB="<publishable_key>"
curl -s -H "apikey: $PUB" -H "Authorization: Bearer $PUB" \
  "$URL/rest/v1/${TABLE}?user_id=eq.<some_id>" | head -3
# [] 빈 결과 = RLS 차단 → service_role 필수
```

**기본 가정**: server-side query 가 본인 row 도 못 볼 수 있다. RLS 정책 단정 X. 어드민/cross-user query 는 **service_role + `import 'server-only'` 가 기본값**.

### 3. 기존 호출 패턴 1개 이상 read

같은 query 를 이미 호출하는 기존 코드 1곳 이상 read. 신규로 짜기 전에 패턴 미러.

- 신규 어드민 = bbakcar-web 의 `require-role.ts` + `getCurrentOrganization` 본문 read (시그니처만 X, 함수 body)
- 신규 모바일 = bbakcar 의 `useVehicles.ts` 또는 동등 hook 본문 read
- 새 API route = 같은 도메인 기존 route 본문 read

### 4. multi-X 가능성 사전 검증

`single()` / `maybeSingle()` 쓰기 전 1초 질문: **정말 single 인가?**

- user → orgs (multi-org membership 흔함, staff 는 거의 2+)
- user → roles (한 user 가 도메인별로 다른 role)
- email → user (legacy duplicate 가능, 같은 이메일 다른 user 2개)
- record → 다른 도메인 entity (1:N 흔함)

**multi 확인 방법**: service_role 로 `count: 'exact'` query 또는 `select *` 후 length 확인. count > 1 면 `single()` 금지.

## auth/session 코드 작성 — 첫 줄 console.log 의무

```ts
export async function getSession(): Promise<Session> {
  const supabase = await createClient()
  const { data: { user }, error: authError } = await supabase.auth.getUser()
  console.log('[getSession] auth.getUser', { userId: user?.id, err: authError?.message })
  if (!user) return null

  const adminClient = createAdminClient()
  const memberRes = await adminClient.from('org_members').select('...').eq(...)
  console.log('[getSession] members', { count: memberRes.data?.length, err: memberRes.error?.message })

  // ... 모든 분기마다 console.log
}
```

이 log 들은 PR 직전 제거. 작성 시점에는 박고 시작. silent debug 금지.

## 외부 ID 매칭 — sub claim 검증

email lookup 후 도출한 user.id 와 로그인 cookie 의 sub claim 이 같은지 검증:

```ts
const { data: { user } } = await supabase.auth.getUser()
console.log('actual sub:', user?.id)  // <- 이게 정본
// email lookup 결과는 보조 데이터일 뿐
```

**같은 email 다른 user 2개 가능** (Supabase Auth duplicate, legacy migration).

## 적용 도메인

- `auth/session.ts`, `requireRole`, `requirePermission`, `getCurrentOrganization` 등 entry guard
- 모든 `*.queries.ts` (server-side SELECT)
- RLS-sensitive 도메인 (members, orgs, profiles, PII 5컬럼 등)
- 신규 repo 가 기존 prod DB 가리키는 모든 경우

## 짧은 진단 순서 (사용자 "안 됨" 시)

1. **console.log 박기** — silent debug 5분 < log 박고 1초 확인
2. **service_role 로 외부 curl** — 진짜 데이터 직접 확인
3. **RLS 차단인지 schema mismatch 인지 multi-row 인지 분기**
4. **기존 패턴과 1:1 비교**

3분 안에 확정. 4번째 시도 전에 도달해야.

## How to apply

- 신규 repo / 신규 query 작성 시 4 의무 확인 → console.log → 첫 동작 확인 → log 제거
- 사용자가 "여전한데?" 2번째 들으면 즉시 console.log + 외부 curl 의 진단 모드 진입
- 이 룰을 위반한 추측-짜기는 사용자 페인 누적 + 신뢰 손상

## Why

**Why**: 2026-05-28 bbakcar-admin getSession 4번 다시 짠 사고. 매번 추측: `app_users.role`(틀린 테이블) → RLS 안 고려 → `maybeSingle()` multi-row 미고려 → `created_at` 없는 컬럼. 외부 curl + console.log 1번이면 1차에 끝났음. 사용자 "여전한데?" 3번 + "반성문 써" 까지 갔음.

**How to judge edge cases**: "내가 이 schema/RLS 직접 확인했나?" 1초 질문. NO 면 추측 작성 금지. service_role curl 30초가 추측 fix 4번보다 짧다.
