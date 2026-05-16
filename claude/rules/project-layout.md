# Project Layout Defaults

**Default: do NOT auto-create project layout directories.**

Work within whatever structure the project already has. Do not invent a baseline structure (`docs/`, `apps/`, `packages/`, `db/`, `.project/`, `data/`, `scripts/`, `templates/`, etc.) on your own initiative.

## When this layout DOES apply

Only when the user explicitly asks for it. Triggers like:
- "set up a monorepo"
- "scaffold the project layout"
- "make the work-log docs"
- "create the baseline structure"

In that case, follow this convention:
- Treat one client/project as one repository by default. Use a monorepo so code, docs, schema, evidence, and planning context travel together.
- Prefer top-level `apps/` for runnable deliverables and `packages/` for shared code. For example, separate real deliverables become separate app packages such as `apps/park-mobile/` and `apps/onyu-mobile/`, not route groups inside one app.
- Keep project context in the repository: `docs/`, `docs/work-log/`, `materials/`, `proposal/`, `design-mockups/`, and `.project/` when present. Do not split `docs/` into a private/local-only repo; it is implementation context.
- Keep data/schema infrastructure in the shape the project actually uses (`supabase/`, `db/`, `prisma/`, etc.). Do not force `db/` if the repo already has a better canonical directory.
- `docs/work-log/_template/` holds templates: `context.md`, `plan.md`, `checklist.md`.
- For non-trivial tasks under that layout, create one folder per task with the three planning docs.
- Prefer `$work-log-harness` or `~/.config/agent-harness-baseline/bin/ensure-work-log-task.sh --title "<task>" --json` at workflow start.
- Do not wire this to SessionStart; create/update work-log folders only for explicit layout requests or non-trivial workflow starts.

## Multi-app and subtree policy

- If requirements, RFPs, stores, deployments, or ownership boundaries say there are two apps, create two app packages under `apps/` even if a single route-group demo would be faster.
- Use `packages/` for shared UI, domain, SDK, DB types, and config instead of copying code between app packages.
- Use Git subtree only as a later extraction/mirroring mechanism when an app/package truly needs its own repository for external team, deployment, or governance reasons. Do not use subtree to hide or separate core project docs.
- Microservice-style `1 app = 1 repo` is an exception for independently governed services. The default for client/product work is `1 project = 1 repo` monorepo.

## Work-log folder naming (MANDATORY)

Work-log task folders are ALWAYS named `docs/work-log/YYYY-MM-DD_<feature>/`.

- Date prefix is **non-optional**, even when an explicit slug is given. Separator between date and feature is `_` (underscore); within the feature use `-`.
- Never create an undated work-log folder (e.g. `rn-supabase-prototype/` is wrong; `2026-05-15_rn-supabase-prototype/` is correct).
- The harness `~/.config/agent-harness-baseline/bin/ensure-work-log-task.sh` enforces this (forces the date prefix, strips a caller-embedded leading date to avoid double-dating, preserves unicode/Korean feature names). Always go through the harness rather than `mkdir`-ing folders by hand.

**Why:** A bare-slug call previously produced undated folders, so logs were not chronologically sortable and the same task could fork. User corrected this and wants it global, not per-call discipline.

**How to apply:** Any project, any session — when creating or referencing a work-log folder expect the `YYYY-MM-DD_<feature>` shape. If you find a non-conforming folder, rename it to the convention. This rule is global (loaded every session via `~/AGENTS.md`); the behavioral enforcement is in the agent-harness-baseline SSOT harness.
