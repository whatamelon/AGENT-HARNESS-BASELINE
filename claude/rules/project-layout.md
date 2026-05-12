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
- For non-trivial tasks under that layout, create `docs/work-log/<task-name-or-date>/` with the three planning docs
- Prefer `$work-log-harness` or `~/.config/claude-sync/bin/ensure-work-log-task.sh --title "<task>" --json` at workflow start.
- Do not wire this to SessionStart; create/update work-log folders only for explicit layout requests or non-trivial workflow starts.
