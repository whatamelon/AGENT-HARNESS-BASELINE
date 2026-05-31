# AIDP Demo Goal Deployment Modes

## Manual

Use when no script runtime exists. Read `SKILL.md`, copy templates, and fill artifacts manually. No claim of automation.

## Portable

Requires Node.js or Python 3. Works without OMX, tmux, hooks, or Vercel.

Capabilities:
- create run artifacts with templates or `init-run.mjs`
- validate run directory with `validate-run.mjs` or `validate_run.py`
- produce benchmark, stage gates, proposal package, completion audit manually

Limits:
- no Team panes
- no Ultragoal checkpoint
- no automatic designslop Stop hook
- no live deploy unless provider installed separately

## Workstation

Requires portable mode plus `omx`.

Capabilities:
- Ultragoal/Codex goal handoff and checkpoint after active-goal reconciliation
- local state under `.omx/`
- manual or native-agent execution lanes

Limits:
- no durable Team unless tmux exists
- no automatic Stop hook unless hooks installed

## Full

Requires workstation mode plus tmux and designslop hooks.

Capabilities:
- durable `omx team` workers
- designslop Stop-hook blocking
- long-running execution and evidence gathering

## Cloud/Product Future

Requires plugin packaging and hosted/central services:
- connector auth for Slack/mail/files/images
- central state store
- worker runner
- deployment provider adapters
- web dashboard

Do not call this mode available until those tools exist.
