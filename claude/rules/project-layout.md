# Project Layout Defaults

**Default: do NOT auto-create project layout directories.**

Work within whatever structure the project already has. Do not invent a baseline structure (`docs/`, `fe/`, `db/`, `.project/`, `data/`, `scripts/`, `templates/`, etc.) on your own initiative.

## When this layout DOES apply

Only when the user explicitly asks for it. Triggers like:
- "set up a monorepo"
- "scaffold the project layout"
- "make the work-log docs"
- "create the baseline structure"

In that case, follow this convention:
- Monorepo with `docs/`, `docs/work-log/`, `fe/`, `db/`, `.project/`
- `docs/work-log/_template/` holds templates: `context.md`, `plan.md`, `checklist.md`
- For non-trivial tasks under that layout, create one folder per task with the three planning docs
- Prefer `$work-log-harness` or `~/.config/claude-sync/bin/ensure-work-log-task.sh --title "<task>" --json` at workflow start.
- Do not wire this to SessionStart; create/update work-log folders only for explicit layout requests or non-trivial workflow starts.

## Work-log folder naming (MANDATORY)

Work-log task folders are ALWAYS named `docs/work-log/YYYY-MM-DD_<feature>/`.

- Date prefix is **non-optional**, even when an explicit slug is given. Separator between date and feature is `_` (underscore); within the feature use `-`.
- Never create an undated work-log folder (e.g. `rn-supabase-prototype/` is wrong; `2026-05-15_rn-supabase-prototype/` is correct).
- The harness `~/.config/claude-sync/bin/ensure-work-log-task.sh` enforces this (forces the date prefix, strips a caller-embedded leading date to avoid double-dating, preserves unicode/Korean feature names). Always go through the harness rather than `mkdir`-ing folders by hand.

**Why:** A bare-slug call previously produced undated folders, so logs were not chronologically sortable and the same task could fork. User corrected this and wants it global, not per-call discipline.

**How to apply:** Any project, any session — when creating or referencing a work-log folder expect the `YYYY-MM-DD_<feature>` shape. If you find a non-conforming folder, rename it to the convention. This rule is global (loaded every session via `~/AGENTS.md`); the behavioral enforcement is in the claude-sync SSOT harness.
