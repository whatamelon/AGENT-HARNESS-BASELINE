# CI verify job 병렬화 (필수 적용)

## 핵심 규칙

> **PR CI 의 lint + typecheck + test + build 류 verify job 은 단일 job 직렬 실행 금지. 각 단계를 독립 job 으로 분리해서 GitHub Actions runner 가 동시에 받아 wall-clock 시간을 절반 이하로 줄인다.**

PR feedback 시간이 직접적으로 머지 속도와 작업 흐름을 좌우한다. 직렬 verify 는 lint fail 도 build 완료 후에야 노출되어 feedback 느림.

## 적용 대상

GitHub Actions 기반 CI 를 사용하는 모든 프로젝트 (`.github/workflows/*.yml`). Node/Next.js/Vite/Rust/Go 등 stack 무관. 다음 단계 중 2개 이상을 단일 job 으로 직렬 실행하는 모든 경우:

- lint
- typecheck
- test (unit/integration)
- build
- format check
- security audit

## 패턴

### Bad — 직렬 단일 job

```yaml
jobs:
  verify:
    name: lint + typecheck + test + build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck
      - run: npm run test
      - run: npm run build
      - run: npm run format:check
```

wall-clock = lint(25s) + typecheck(20s) + test(20s) + build(45s) + format(17s) + setup(25s) = ~2:30. lint fail 시 모든 단계 끝까지 대기.

### Good — 병렬 job 분리 + 합본 summary

```yaml
on:
  pull_request:
  push:
    branches: [main, develop]

concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

env:
  # workflow-level: 5 verify job 모두에 공통 적용 (반복 제거)
  NEXT_PUBLIC_SUPABASE_URL: https://example.supabase.co
  # ... 다른 placeholder env

jobs:
  lint:
    name: lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci --prefer-offline
      - run: npm run lint

  typecheck:
    name: typecheck
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci --prefer-offline
      - run: npm run typecheck

  test:
    name: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci --prefer-offline
      - run: npm run test:ci

  build:
    name: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci --prefer-offline
      - run: npm run build

  format:
    name: format check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci --prefer-offline
      - run: npm run format:check

  # 합본 status: 기존 required check 이름을 보존
  verify:
    name: lint + typecheck + test + build
    needs: [lint, typecheck, test, build, format]
    if: always()
    runs-on: ubuntu-latest
    steps:
      - name: aggregate verify results
        run: |
          if [ "${{ needs.lint.result }}" != "success" ] || \
             [ "${{ needs.typecheck.result }}" != "success" ] || \
             [ "${{ needs.test.result }}" != "success" ] || \
             [ "${{ needs.build.result }}" != "success" ] || \
             [ "${{ needs.format.result }}" != "success" ]; then
            echo "::error::One or more verify jobs failed."
            echo "lint:      ${{ needs.lint.result }}"
            echo "typecheck: ${{ needs.typecheck.result }}"
            echo "test:      ${{ needs.test.result }}"
            echo "build:     ${{ needs.build.result }}"
            echo "format:    ${{ needs.format.result }}"
            exit 1
          fi
```

wall-clock = max(lint, typecheck, test, build, format) + setup(25s) = build 45s + 25s = ~1:10. lint fail 25s 안에 알림.

## 핵심 결정

1. **setup-node@v4 `cache: 'npm'`** 가 `~/.npm` 캐싱 → 각 job 의 `npm ci` 는 cache hit 시 ~10s. 5 job × 10s = 50s overhead 감수.
2. **`npm ci --prefer-offline`** 으로 cache hit 최대화. cache miss 시 network fallback.
3. **합본 summary job** 으로 기존 required check 이름 보존:
   - auto-merge 가 등록한 check 이름이 깨지지 않음
   - branch protection rule (Pro plan) 의 required check 호환
   - 한 개 job 이라도 fail 시 summary fail → 머지 차단
4. **workflow-level `env`** 으로 placeholder secret 반복 제거.
5. **`concurrency.cancel-in-progress: true`** 로 push 마다 이전 run 취소 → runner 낭비 차단.

## 트레이드오프 (수용)

- Actions minutes 사용 증가: 5 job × ~50s overhead = ~250s vs 기존 ~150s = **약 1.7배 minutes 비용**
- 캐시 miss 시 setup 더 느릴 수 있음 (~15s → ~25s)

비용 < feedback time 단축 가치. PR 머지 throughput 가 더 중요한 프로젝트에서 강력 권장.

## 다른 stack 적용

- **pnpm**: `cache: 'pnpm'` + `pnpm install --prefer-offline` (또는 `--frozen-lockfile`)
- **Yarn 1**: `cache: 'yarn'` + `yarn install --frozen-lockfile --prefer-offline`
- **Yarn berry**: `actions/cache@v4` 로 `.yarn/cache` 명시 캐싱
- **Rust**: `Swatinem/rust-cache@v2` action + cargo job 분리 (clippy / test / build)
- **Go**: `cache: true` (setup-go@v5) + go vet/test/build 분리
- **Python uv**: `astral-sh/setup-uv@v3` + uv sync 캐시 + ruff/mypy/pytest 분리

## How to apply

- 새 프로젝트 CI 설정 시 처음부터 분리된 job 구조로 작성. 한 job 에 step 3 개 이상 직렬 금지 (lint+typecheck+test+build 류).
- 기존 프로젝트 onboarding 시 첫 작업 중 하나로 CI 병렬화 PR 만들기. 다른 작업의 PR feedback 속도 즉시 개선.
- 합본 summary job 이름은 기존 required check 이름 그대로 유지. 변경 시 reviewer 가 branch protection / auto-merge 수동 업데이트 필요.
- Actions minutes plan 한계 (Free: 2,000/월, Team: 3,000/월) 에 가까운 프로젝트는 비용 영향 측정 후 결정.

## Why

**Why:** 단일 job 직렬 실행은 lint(25s) 에서 fail 인 PR 도 build(45s) 끝까지 기다리고 알림. PR feedback 시간이 머지 throughput 의 직접 bottleneck. GitHub Actions runner 는 동시 실행 가능한 idle 자원이고 job 분리만으로 wall-clock 50%+ 단축 가능.

빡차 워크스페이스 ralph 자동 진행 중 7 admin-ux PR stack 의 CI fail iteration 마다 ~2:30 wait 가 누적 ~30분 이상 소요됐고 사용자가 직접 "병렬 불가능이냐?" 지적함 (2026-05-21). 그 사례로 글로벌 룰 승격.

**How to judge edge cases:**
- 단계 간 의존성이 있어서 병렬화하면 정확성 깨지는 경우 (예: typecheck 가 generate-types 출력 의존) — 의존 단계는 한 job 으로 묶고 나머지만 분리.
- Actions minutes 가 plan 한계에 근접 — `paths-ignore` 로 docs-only PR 의 verify 스킵 등 다른 최적화 우선.
- 매우 빠른 verify (전체 ~30s 미만) — 분리 overhead 가 더 큼. 그대로 둠.
