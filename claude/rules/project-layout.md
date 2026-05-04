# Project Layout Defaults

- Treat every newly created development project as a monorepo unless the user explicitly requests otherwise.
- Whenever creating or working in a development project, ensure this baseline project structure exists:
  - `docs/`
  - `docs/work-log/`
  - `fe/`
  - `db/`
  - `.project/`
- Keep `docs/work-log/_template/` with these planning document templates:
  - `context.md` — why this work exists, how it came to be planned or implemented, relevant requests/evidence/constraints.
  - `plan.md` — how the work will be implemented, expected change areas, validation strategy, risks.
  - `checklist.md` — completion checklist for implementation quality and acceptance criteria.
- For every non-trivial task, create a dedicated directory under `docs/work-log/<task-name-or-date>/` and maintain exactly these three planning documents before or alongside implementation: `context.md`, `plan.md`, and `checklist.md`.
- Simple one-step tasks may skip a dedicated work-log directory, but any feature, refactor, bug investigation, architecture change, data/schema change, UI flow, or multi-file edit is non-trivial by default.
