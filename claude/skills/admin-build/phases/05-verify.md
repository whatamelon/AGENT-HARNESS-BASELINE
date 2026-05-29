# Phase 05 — Verify

4-layer verifier 실행.

## 실행

```bash
admin-build verify          # L1+L2+L3+L4
admin-build verify --fast   # L1+L2 only (dev iteration)
```

## Layer 별 contract

### L1 — static-grep (Python)

- `~/.config/agent-harness-baseline/admin-design/machine/checklist.yaml` L1 probes 실행
- `~/.config/agent-harness-baseline/admin-security/_secret-leak.yaml` 패턴 실행
- exit 0 = pass, 1 = fail

### L2 — tsx-ast (Node + ts-morph)

- `machine/component-contracts.yaml` 컴포넌트 존재/props 검증
- structured query keys, zodResolver, route permission, no-tinted-card 등 AST 룰
- 의존성: `pnpm add -D ts-morph js-yaml` (target repo)

### L3 — runtime (Playwright + RBAC)

- `machine/state-taxonomy.yaml` page_type_matrix 의 required state 모두 렌더링 확인
- `machine/viewport-matrix.yaml` 5종 viewport 렌더 확인 + horizontal overflow 검출
- `admin-security/_rbac-matrix.yaml` fixture 4종 (owner/ops/viewer/forbidden) × route × action 확인
- 의존성: `pnpm add -D playwright` + `npx playwright install --with-deps chromium`
- 필수 env: `ADMIN_BUILD_BASE_URL`, `ADMIN_TEST_TOKEN_{owner,ops,viewer,forbidden}`
- 필수 artifact: `.admin-build/routes.json` (orchestrator 가 phase 02 plan 에서 emit)

### L4 — axe + screenshot

- `@axe-core/playwright` AA 룰
- `playwright` screenshot for every (route × viewport)
- 결과: `.admin-build/runs/<ts>/screenshots/<route>-<viewport>.png`

## Fail 처리

verifier fail → `.admin-build/VERIFIER_FAIL` marker 생성 → Stop hook 이 continue → orchestrator 가 repair prompt → 해당 lane worker 에 회귀.

## 가속 모드 (dev iteration)

`--fast` 는 L1+L2 만. 미 가속 (전체) 는 budget 의 마지막 단계에서만.
