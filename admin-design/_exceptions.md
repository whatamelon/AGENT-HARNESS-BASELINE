---
slug: exceptions
role: governance
description: SSOT rule 예외 등록 절차. Tier 0 는 등록 불가.
---

# Exceptions — SSOT rule 예외 등록

## 절차

1. 위반 발생 시 verifier 가 `.admin-build/runs/<ts>/exceptions.yaml` 자동 draft 생성.
2. 사람이 다음 항목 채워서 PR 로 review:
   - `probe_id` (위반 probe id)
   - `path` (위반 파일 경로)
   - `rule_section` (위반된 SSOT section)
   - `tier` (위반 rule tier — Tier 0 는 등록 불가)
   - `reason` (예외 사유 — 구체적, 도메인 제약/license/기존 코드 등)
   - `approver` (PR reviewer GitHub handle)
   - `expires_at` (YYYY-MM-DD — 영구 예외 금지, 최대 6개월)
   - `mitigation` (예외 동안 위험 완화 조치)
3. reviewer 가 approve → exceptions.yaml 가 verifier 의 allow_list 로 변환.
4. expires_at 도래 시 verifier 자동 재발화.

## Tier 0 절대 불가

`00-non-negotiable.md` 의 모든 rule. dark mode/colored card/frontend-only security/mock prod data/service_role browser leak/AG Grid Enterprise without license/skip required state 등.

## exceptions.yaml schema

```yaml
exceptions:
  - probe_id: no-tinted-card-background
    path: src/components/admin/marketing-spotlight-card.tsx
    rule_section: 04-tokens.md §4.6
    tier: 1
    reason: "marketing eyebrow 위젯 한 곳만 brand promo card — DESIGN.md §X.Y 의 marketing surface override 룰 적용."
    approver: "@design-lead"
    expires_at: "2026-09-01"
    mitigation: "본 위젯은 admin/marketing 도메인에만, 비-admin 페이지 X."
```

## 거부 사례

다음 예외 신청은 자동 거부:

- "임시로 dark mode 켜야 합니다" → Tier 0 위반, 거부
- "이번 PR 만 mock data 살려야 합니다" → Tier 0 위반, 거부
- "RLS 비활성화로 디버깅 편하게" → Tier 0 위반, 즉시 reject + security-reviewer 알림
- "expires_at 무기한" → 거부, 최대 6개월
