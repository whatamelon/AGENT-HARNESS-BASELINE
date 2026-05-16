# Shared DESIGN.md Quality Harness

This folder is the central template for the Claude Code/Codex DESIGN.md quality loop.
It is shared by `~/.config/agent-harness-baseline`, so the company MacBook Pro and home MacBook Air can install the same harness into project repos.

## Install into a project

From a Next.js project root:

```bash
getdesign init --force
getdesign init-harness --force
pnpm install
pnpm lint
pnpm build
pnpm test:visual
```

`getdesign init-harness` copies:

- `scripts/visual-check.mjs`
- `CLAUDE_CODE_PROMPT.md`

and updates `package.json` with:

- `scripts.test:visual = node scripts/visual-check.mjs`
- `@axe-core/playwright`
- `@playwright/test`


## Mobile Expo / React Native preview harness

For comparison or prototype Expo apps that run through `expo start --web`, install the shared iPhone preview shell:

```bash
getdesign init-mobile-harness --path packages/mobile-ui/src/design-harness.tsx
```

The command copies `mobile-expo-iphone17-pro-max-harness.tsx` into the target project. The template exports `Iphone17ProMaxDesignHarness`, which:

- centers a phone mock on the browser canvas;
- uses a 440×956 inner app viewport with a 2px iPhone 17 Pro Max class bezel;
- overlays Dynamic Island and home indicator chrome without intercepting RN gestures;
- injects safe-area frame/insets directly (`top: 59`, `bottom: 34`) so headers do not sit under the Dynamic Island;
- falls back to the real `SafeAreaProvider` on native platforms.

Use this only around comparison/prototype app roots, typically around the Expo Router `Stack` in `_layout.tsx`. Do not ship the browser phone shell inside production native app flows.

## UI data contract

The harness expects the app to mark quality-critical UI with these attributes:

- `data-forced-colors-boundary`
- `data-reduced-motion-static`
- `data-horizontal-scroll-ok`
- `data-content-stress`
- `data-density-group` and `data-density-min`
- `data-interaction-probe`
- `data-interaction-state`
- `data-visual-priority`
- `data-copy-quality`

The current template is intentionally strict and modeled after `design-loop-test`. For a product app, keep the same audit concepts and adjust project-specific text expectations only when the replacement remains evidence-based.

## Current gates

1. Dark mode contrast
2. Responsive viewport matrix
3. Keyboard focus
4. Axe accessibility
5. Reduced motion
6. Forced colors / high contrast
7. Text zoom / large text reflow
8. Content stress / localization overflow
9. Visual density / hit-area separation
10. Interaction state matrix
11. Visual hierarchy / section priority
12. Copy quality / anti-generic UI text

## Freshness

The harness writes current evidence to `artifacts/visual-check.json` and screenshots under `artifacts/`. Do not claim completion from stale artifacts; rerun `pnpm test:visual` after UI, copy, token, or dependency changes.
