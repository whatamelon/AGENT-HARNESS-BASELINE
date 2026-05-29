# Phase 06 — Finalize

verifier PASS 후 run artifact 마무리.

## 의무 산출물

```
.admin-build/runs/<ts>/
├── input.yaml
├── ssot_attestation.json          (worker 별로 여러 개)
├── plan.md
├── critic.md / verdict.yaml
├── worker-logs/<lane>.jsonl
├── changed-files.txt
├── verifier-report.json
├── rbac-report.json
├── screenshots/<route>-<viewport>.png
├── exceptions.yaml                (Tier 1 예외만, Tier 0 등록 불가)
├── assumptions.md                 (intake 누락 default 모두 기록)
├── routes.json                    (L3/L4 verifier 용)
└── final-verdict.md
```

## final-verdict.md 구조

```markdown
# Verifier Verdict — <ts>

**Overall:** PASS

## SSOT
- version: admin-design@1.0.0
- manifest hash: sha256:f3a...

## Implemented
- routes (N)
- foundation components (N)
- feature pages (N)
- RBAC policies (N)
- audit triggers (N)

## Verifier
- L1: PASS (N probes, 0 fatal)
- L2: PASS (N rules, 0 fatal)
- L3 runtime: PASS (N routes × 5 viewport × 4 fixture)
- L3 RBAC: PASS (N forbidden-bypass attempts blocked)
- L4 axe: PASS (0 critical, 0 serious)
- L4 screenshot: N artifacts

## Assumptions
- (intake 누락 default 결정 list)

## Exceptions (Tier 1)
- (적용된 예외 list; Tier 0 는 등록 불가)

## Next manual steps
- (사람이 처리해야 할 운영 작업 — production 배포, secret 주입, etc)
```

## Replay 가능성

`admin-build replay <run-id>` 로 동일 input + SSOT version 으로 재실행. CI 에서 회귀 검출 용도.

## 운영 흐름 (이후)

1. PR 생성 (whatamelon 계정 — `[[hermes-pr-protocol]]` 글로벌 룰 적용).
2. PR body 에 본 verdict 첨부.
3. Hermes 또는 인간 리뷰 → merge.
4. main 적용 후 prod 배포는 사람 게이트.
