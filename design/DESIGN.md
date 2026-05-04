# DESIGN.md — Shared Design Operating System

This is the single source of truth for product, UI, interaction, and visual design direction across Claude Code, Codex, and both Macs.

## Source and sync contract

- Canonical file: `~/.config/claude-sync/design/DESIGN.md`
- Local entrypoints:
  - `~/DESIGN.md`
  - `~/.claude/DESIGN.md`
  - `~/.codex/DESIGN.md`
- Retrieval guide: `getdesign.md`
- Do not fork machine-local copies. If design direction changes, update the canonical file and run `sync-attest`.

## When to load this

Load this before work involving:

- UI/UX, frontend implementation, design systems, visual polish
- product flows, landing pages, dashboards, onboarding, settings, admin screens
- copy/layout hierarchy, accessibility, interaction states, component selection
- visual QA or design review

For non-visual backend work, only load it if product experience, API ergonomics, or developer-facing UX is affected.

## Design principles

1. **Outcome first** — state the user outcome, primary action, constraints, and validation evidence before implementation detail.
2. **Clarity over decoration** — hierarchy, spacing, and copy must make the next action obvious.
3. **Calm density** — information-rich screens are allowed, but grouping, whitespace, and progressive disclosure must prevent cognitive overload.
4. **Accessible by default** — keyboard access, visible focus, semantic structure, sufficient contrast, and screen-reader labels are baseline requirements.
5. **Systematic consistency** — reuse existing tokens, components, navigation patterns, and copy tone before inventing new ones.
6. **Evidence beats taste** — design decisions should be justified by user task, constraints, screenshots, metrics, or comparable product patterns.
7. **Responsive from the start** — desktop, tablet, and mobile behavior should be intentionally defined, not patched later.
8. **Fast perceived performance** — skeletons, optimistic states, empty states, and error recovery are part of design, not afterthoughts.

## Default UI quality bar

For every UI change, verify:

- [ ] Primary user goal is visible above the fold or immediately discoverable.
- [ ] Primary/secondary/destructive actions are visually distinct.
- [ ] Loading, empty, error, disabled, success, and long-content states are handled.
- [ ] Layout works at narrow, medium, and wide breakpoints.
- [ ] Color contrast and focus states are acceptable.
- [ ] Copy is concise, specific, and action-oriented.
- [ ] Component choices match the existing design system or explicitly justify deviation.
- [ ] Visual QA evidence exists: screenshot, browser check, story, or deterministic test where applicable.

## Agent behavior

When design context is relevant:

1. Read `getdesign.md` for the retrieval workflow.
2. Read this `DESIGN.md` for durable principles.
3. Inspect any project-local `DESIGN.md`, style guide, Storybook, Figma export, theme config, or component library.
4. Summarize the active design constraints before proposing or editing UI.
5. Validate visually when possible.

## Project override rule

A project-local `DESIGN.md` overrides this global file for that project, but it should not contradict accessibility, safety, or user-explicit requirements.

If project and global guidance conflict:

1. Follow user instructions first.
2. Follow project-local `DESIGN.md` next.
3. Follow this global `DESIGN.md` next.
4. Ask only if the conflict changes product behavior or brand-critical visuals.
