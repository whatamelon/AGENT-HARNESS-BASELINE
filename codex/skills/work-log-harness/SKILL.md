---
name: work-log-harness
description: Create or reuse the user's per-task docs/work-log harness. Use when starting non-trivial implementation, refactor, investigation, architecture, schema/data, UI flow, or team/worker work that needs context.md, plan.md, and checklist.md under docs/work-log/<task>/.
---

# Work Log Harness

Use this skill to bootstrap the user's standard task documentation without relying on SessionStart auto-mutation.

## When to Use

- A task is non-trivial: feature, refactor, bug investigation, architecture change, schema/data change, UI flow, multi-file edit, or coordinated worker lane.
- The user asks to "make the work-log docs", "작업 로그", "context/plan/checklist", or "하네스".
- A team/worker lane needs a durable task folder before implementation.

## Contract

- Do not create project layout merely because a session started.
- Create the work-log folder at workflow start or when explicitly requested.
- Do not overwrite existing files.
- Keep the active task folder as the single source of truth for context, plan, checklist, validation, and remaining risks.

## Command

Run from the target repository:

```bash
~/.config/claude-sync/bin/ensure-work-log-task.sh --title "<task title>" --json
```

Optional arguments:

```bash
--root <repo-or-project-dir>
--slug <stable-task-slug>
```

The command creates or reuses:

```text
docs/work-log/<slug>/context.md
docs/work-log/<slug>/plan.md
docs/work-log/<slug>/checklist.md
```

## Workflow

1. Choose a concise task title and stable slug.
2. Run the command and capture the returned `work_log_dir`.
3. Fill `context.md` with the user request, evidence, constraints, decisions, and related files.
4. Fill `plan.md` with target outcome, approach, expected change areas, validation strategy, and risks.
5. Keep `checklist.md` current as work proceeds.
6. In team mode, give each worker the relevant work-log folder and require final evidence updates.

## Done Criteria

- `context.md`, `plan.md`, and `checklist.md` exist for the task.
- Non-trivial work references the task folder in final status or handoff.
- Checklist records validation evidence or explicit validation gaps.
