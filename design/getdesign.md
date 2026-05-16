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
