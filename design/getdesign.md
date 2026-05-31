# getdesign.md — Design Context Retrieval Workflow

Use this file when a task needs product, UI, UX, visual, or interaction design context.

## Quick commands

```bash
getdesign                 # show active design context and project-local docs
getdesign init            # copy shared DESIGN.md/getdesign.md into current project
getdesign init --force    # overwrite current project copies
getdesign init-harness --force   # install shared visual check harness
getdesign init-mobile-harness --path packages/mobile-ui/src/design-harness.tsx
getdesign add cursor      # install a getdesign.md catalog inspiration via npx
getdesign doctor          # verify shared entrypoint symlinks
```

`getdesign` is an alias for `~/.config/agent-harness-baseline/bin/getdesign.sh`. With no arguments, it prints the active global design entrypoints and discovers project-local design files from the current directory upward.

## ANDS preset selection (Flutter 디자인 하네스)

디자인 톤은 **2개 독립 노브**로 선택한다. 둘을 혼동하지 말 것.

| 노브 | 무엇을 정함 | 범위 | 메커니즘 |
|---|---|---|---|
| **① Foundation 프리셋** | radii·type·density·brand accent·state 색 (전체 톤) | **워크스페이스 공유** (`packages/ds/tokens/tokens.json` 1개) | `bin/ds-preset.sh <name>` |
| **② brand_seed** | 앱의 Primary CTA 색 | **앱별** (런타임) | flutter_app 브릭 `brand_seed` var → `buildTheme(seed:)` |

### ① 어떤 foundation 프리셋? (tone-fit 결정표)

| 앱 성격 | 프리셋 | 문서 |
|---|---|---|
| 커머스·카탈로그·상품 다수·고밀도 그리드 (리테일/패션) | `uniqlo` | [`DESIGN-UNIQLO.md`](./DESIGN-UNIQLO.md) |
| 에디토리얼·프리미엄·여백·콘텐츠 hero / 예약·금융·B2B 운영툴 | `ands` (기본) | [`DESIGN.md`](./DESIGN.md) |

```bash
ds-preset.sh list      # 사용 가능 프리셋 + 현재 활성(*) 표시
ds-preset.sh status    # 현재 활성 프리셋
ds-preset.sh uniqlo    # 활성화: tokens.json 교체 + Dart 재생성 + drift 검증 (원자적, 실패 시 복원)
ds-preset.sh ands      # base ANDS 로 복귀
ds-preset.sh uniqlo --test   # gen 후 flutter test 까지
```
(`bin/ds-preset.sh`. 새 프리셋은 `packages/ds/tokens/presets/<name>.json` 에 동일 스키마 드롭인으로 추가.)

### ② brand_seed 규칙

- **UNIQLO 톤이면 `brand_seed = 0xFF111114`(ink).** Primary CTA = 블랙. 레드는 brand accent(`state.brand`)지 Primary 가 아니다. 브랜드 레드를 seed 에 넣지 말 것(토큰 안티패턴).
- 별도 브랜드 Primary 색이 정당한 앱만 그 색을 seed 로. 단 "액션색 ≠ 로고색"일 수 있음을 먼저 판단.

### 캐비엇

- 공유 ds(`path: ../../packages/ds`) = **워크스페이스당 foundation 1개.** 한 워크스페이스 안 앱들이 서로 다른 foundation 이 필요하면 ds 공유를 깨야 한다(per-app vendor 또는 별 워크스페이스). 같은 톤이면 그대로 공유.

## Retrieval order

1. **User request** — explicit visual/product requirements in the current turn are highest priority.
2. **Project-local design files** — nearest `DESIGN.md`, `design.md`, `docs/design*.md`, Storybook docs, theme config, component docs.
3. **Global design OS** — `~/DESIGN.md` / `~/.claude/DESIGN.md` / `~/.codex/DESIGN.md`.
4. **Available skills** — use relevant design skills such as `frontend-design`, `ui-ux-pro-max`, `web-design-guidelines`, `tailwind-design-system`, `shadcn-ui`, or framework-specific UI skills.
5. **Runtime evidence** — screenshots, browser inspection, accessibility checks, tests, and user feedback.

## Required design context summary

Before doing design work, produce a short summary with:

- Product goal:
- Primary user/action:
- Surface/component/page:
- Existing design system or project style:
- Constraints:
- Validation plan:

## Mobile Expo comparison harness

For React Native / Expo Web comparison apps, install the shared iPhone preview shell instead of hand-building device chrome every time:

```bash
getdesign init-mobile-harness --path packages/mobile-ui/src/design-harness.tsx
```

Use it only for prototype/comparison web previews. It renders a centered iPhone 17 Pro Max class shell with a 440×956 app viewport, 2px bezel, Dynamic Island overlay, home indicator, and direct safe-area context values (`top: 59`, `bottom: 34`) so Expo Web screens behave like native RN safe-area layouts. Production native apps must keep using the real `SafeAreaProvider` path.

## Output expectations

For implementation tasks:

- Make the smallest coherent design change that satisfies the goal.
- Preserve existing design language unless the task asks for a new direction.
- Include state coverage: loading, empty, error, success, disabled, long content.
- Verify with screenshots/browser checks when UI is rendered locally.

For review tasks:

- Identify hierarchy, spacing, contrast, affordance, consistency, accessibility, and responsive issues.
- Prioritize issues by user impact.
- Provide concrete fixes, not vague taste comments.

## Sync certification

After editing shared design files, run:

```bash
cd ~/.config/agent-harness-baseline
bash bin/sync-attest.sh
```

PASS means the design files are linked into Claude Code and Codex and the shared environment is current.


## DESIGN.md structure checklist

A strong DESIGN.md should include these sections:

1. Visual Theme & Atmosphere
2. Color Palette & Roles
3. Typography Rules
4. Component Stylings
5. Layout Principles
6. Depth & Elevation
7. Do's and Don'ts
8. Responsive Behavior
9. Mobile Expo Preview Harness
10. Agent Prompt Guide

If a project-local DESIGN.md is missing these sections, improve it before major UI work or explicitly document which project design system replaces them.
