---
name: aidp-demo-goal
description: "[OMX] Run AIDP/FDE proposal-demo goal harness: turn customer briefs into evaluator-gated prototype runs with Ultragoal-owned durable objective, Team-backed execution evidence, benchmark rubrics, deployment/demo readiness, and enterprise completion audit. Use whenever user asks for AIDP demo goals, proposal prototype automation, customer demo harness, 10-30h autonomous demo build, FDE proposal demo, or aidp-demo-goal."
---

# AIDP Demo Goal

Use this skill to plan and drive enterprise proposal-demo runs for AIDP/Wishket FDE work. It is a skill-first implementation surface for the `/goal` harness concept: customer brief -> research -> plan -> design -> development -> QA -> deployment -> demo readiness -> completion audit.

## Purpose

`aidp-demo-goal` exists to create proposal-meeting impact: working prototype plus evidence package, not slides only.

It combines:
- Codex goal mode: active-thread focus/accounting.
- `$ultragoal`: durable objective/story ledger and checkpoints.
- `$team`: durable tmux workers for long-running parallel execution.
- This skill: AIDP proposal-demo run state, stage gates, benchmark/evaluator policy, deployment evidence, demo package, completion audit.

## Core Contract

- First version is enterprise-grade; do not shrink to MVP unless user explicitly changes scope.
- `/goal` product idea is implemented here as `$aidp-demo-goal` skill surface.
- Ultragoal remains durable goal truth.
- Team workers return task status and evidence only.
- Workers must not mutate Codex goal state, `.omx/ultragoal`, or final completion state.
- Leader owns gate transitions, fresh `get_goal` snapshots, Ultragoal checkpoints, and final completion decision.
- Security, privacy, deployment evidence, and final completion gates are non-overridable.
- Mock deployment evidence is allowed only in tests; real completion needs live deploy URL or approved offline fallback evidence.


## Environment Modes

Run the doctor before assuming full automation:

```sh
node <skill-dir>/scripts/doctor.mjs
# or, when Node.js is unavailable but Python exists:
python3 <skill-dir>/scripts/doctor.py
```

Mode meanings:

| Mode | Requirements | Allowed behavior |
|---|---|---|
| `portable` | skill files + Node.js or Python 3 | create/validate run docs, produce manual handoff, no hidden runtime mutation |
| `workstation` | portable + `omx` | use Ultragoal artifacts/checkpoints when active goal matches; Team may be unavailable |
| `full` | workstation + `tmux` + hooks/designslop | use durable Team, Stop-hook designslop gate, long-running orchestration |

Fallback rules:
- If `omx` is missing, do not invoke `$ultragoal`, `$team`, or `omx` commands; create portable run artifacts and print manual next commands.
- If `tmux` is missing, do not launch Team; use native subagents only for bounded analysis or emit Team launch text.
- If designslop hooks are missing, run audit manually when available: `python3 ~/.config/claude-sync/claude/hooks/designslop-audit.py <repo> --quiet`; if unavailable, record `designslop_unavailable` in completion audit and require human visual/design review.
- If Vercel is missing or credentials unavailable, do not claim deploy completion; use another provider adapter or approved offline fallback.
- If Node.js is missing, prefer Python fallback scripts. If both Node.js and Python 3 are missing, use templates manually and mark validation as manual.

## Run Directory

Create one run directory per customer/demo goal:

```text
.omx/goal-runs/<run-id>/
  run.json
  lock.json
  brief.md
  events.jsonl
  stage-gates.json
  benchmark-rubric.json
  traceability-matrix.md
  team/
    launch.md
    evidence.jsonl
    terminal-summary.md
  research/
  planning/
  design/
  implementation/
  qa/
  deployment/
    vercel.json
    smoke.txt
    rollback.md
  proposal-package/
    demo-script.md
    architecture-brief.md
    benchmark-scorecard.md
    roadmap.md
    security-privacy-audit.md
  completion-audit.json
```

Use templates in `templates/` when creating `brief.md`, proposal package checklist, and completion audit.

## Invocation Patterns

When user says any of these, use this skill:
- `$aidp-demo-goal "build demo for customer X"`
- `aidp-demo-goal로 제안 데모 목표 잡아줘`
- `고객 제안 미팅용 프로토타입 goal 만들어줘`
- `10-30시간 돌릴 AIDP demo harness 만들어줘`
- `FDE proposal demo 자동화해줘`

## Workflow

### 1. Intake and Context Snapshot

Capture:
- customer/problem/industry
- meeting date and desired wow moment
- target users and stakeholder pains
- available assets/data/API/mock data
- data classification: `public|internal|confidential|restricted`
- deployment target and constraints
- success criteria and demo story

If no `.omx/context/<slug>-*.md` exists, create one with task, outcome, facts, constraints, unknowns, touchpoints.

### 2. Create Goal Run Artifacts

Create `.omx/goal-runs/<run-id>/` and seed. Prefer deterministic init script when Node.js is available:

```sh
node <skill-dir>/scripts/init-run.mjs \
  --slug <customer-demo-slug> \
  --customer "<customer>" \
  --industry "<industry>" \
  --data-class internal \
  --objective "<proposal-demo objective>" \
  --wow "<meeting wow moment>"
```

The script creates:
- `brief.md`
- `run.json` matching `schemas/run.schema.json`
- `lock.json` matching state contract below
- empty `events.jsonl`
- initial `stage-gates.json`
- benchmark/proposal/deployment placeholders

Validate with:

```sh
node <skill-dir>/scripts/validate-run.mjs .omx/goal-runs/<run-id>
# or Python fallback:
python3 <skill-dir>/scripts/validate_run.py .omx/goal-runs/<run-id>
```

### 3. Reconcile Codex and Ultragoal State

Before any mutating action:
1. Call `get_goal`.
2. Read `.omx/ultragoal/goals.json` and `.omx/ultragoal/ledger.jsonl` when present.
3. Classify active goal state:
   - `none`: create goal only from approved handoff.
   - `same`: continue/resume.
   - `different`: block; do not call `create_goal`; write manual recovery note.

Use `$ultragoal` for durable goal/story creation and checkpointing. Shell commands must not pretend to mutate hidden Codex goal state.

### 4. Build Benchmark Rubric Before Design/Dev

Research stage must produce:
- at least 3 reference/best-in-class products or services
- competitor/reference matrix
- weighted benchmark rubric using `schemas/benchmark-rubric.schema.json`
- citations and source currentness policy
- pass threshold and scorer identity

Default dimensions:
- business fit
- workflow coverage
- UX clarity
- speed/performance
- enterprise readiness
- demo wow factor

Business fit should be highest weight unless user gives stronger reason.

### 5. Stage-Gated Execution

Stages:
1. Intake
2. Research
3. Planning
4. Design
5. Development
6. QA
7. Deployment
8. Demo Readiness
9. Completion

No stage advances without required artifacts, schema pass, threshold pass, and reviewer/evaluator verdict.

Non-overridable gates:
- security/privacy
- deployment evidence or approved offline fallback
- completion audit
- active goal mismatch
- worker-origin goal mutation

### 6. Team Orchestration Boundary

Use `$team` only when durable tmux workers are appropriate and available. Otherwise use native subagents for bounded analysis only.

Default Team launch shape:

```sh
omx team 6:executor "Implement AIDP demo goal run from .omx/goal-runs/<run-id>. Preserve Ultragoal leader ownership. Workers execute lanes only and return evidence."
```

Recommended lanes:
1. run schemas/state + atomic event log
2. Ultragoal/Codex adapter
3. StageGateEngine + watchdog
4. benchmark/evaluator engine
5. TeamAdapter + evidence ingestion
6. deployment/proposal package + tests

Specialist reviews happen after Team or as native subagents:
- `security-reviewer`: privacy/secrets/deploy boundaries
- `test-engineer`: test adequacy and flake risk
- `verifier`: completion evidence
- `code-reviewer`: final quality
- `architect`: state ownership and tradeoffs


### 6.1 Design Harness Integration

Design stage must integrate both visual-quality and anti-slop gates when available:

1. Use `$design` or equivalent to create/refresh `DESIGN.md` or `design/DESIGN.md` from customer evidence, benchmark, and demo story.
2. Establish visual reference or live baseline for core demo route.
3. Use `$visual-ralph` / `$visual-verdict` where available; target final verdict score `>= 90`.
4. Run designslop gate:
   - full mode: Stop hook blocks A-grade violations automatically.
   - portable/workstation mode: run `designslop-audit.py <repo> --quiet` when installed.
   - if unavailable, require human review and record gap in completion audit.
5. Completion evidence should include `DESIGN.md`, reference path, screenshot path, visual verdict JSON, designslop audit output or unavailable reason.

### 7. Deployment and Demo Readiness

Default web prototype provider: Vercel.

Required live deployment evidence:
- deployment URL
- deployment id
- build log path
- runtime log path or checked status
- smoke command/result
- screenshot path if available
- rollback command or previous deployment link

Approved offline fallback can be used only when external deploy is blocked by customer/security policy, provider outage, or missing credentials. Fallback must include reason, approver, static/video/screenshot/smoke transcript, and limitations. It cannot override security/privacy or final completion audit.

### 8. Completion Gate

Do not call `update_goal({status: "complete"})` until all are true:
- all stage gates pass
- Team terminal summary has no critical failed lane or portable fallback records no Team launch
- benchmark score meets threshold or approved delta is documented
- design evidence passes: `DESIGN.md`, reference/screenshot, visual verdict `>=90` when available, designslop A violations 0 or documented unavailable/human review
- QA/security/privacy checks pass
- live URL smoke passes or approved fallback exists
- proposal package complete
- completion audit maps every original objective to evidence
- final cleaner/no-op report exists when files changed
- `$code-review` or equivalent final review is clean
- fresh `get_goal` snapshot captured
- Ultragoal final checkpoint recorded with quality gate JSON

Final quality gate JSON should include cleaner, verification, code review, deployment, security, and proposal package evidence.

## Atomic State Contract

`lock.json` must include:
- `run_id`
- `active_goal_state`
- `codex_goal_snapshot_id`
- `ultragoal_goal_id`
- `leader_session`
- `leader_epoch`
- `lock_seq`
- `lock_idempotency_key`
- `last_event_id`
- `last_event_hash`
- `artifact_hash`
- `last_heartbeat_at`
- `resume_policy`

Write rules:
- Compare-and-swap on `run_id`, `leader_epoch`, `lock_seq`, `last_event_hash`.
- Repeated `lock_idempotency_key` returns previous result without duplicate event.
- New leader increments `leader_epoch` only after stale threshold and matching active Codex goal verified.
- Older `leader_epoch` writes are rejected.
- `artifact_hash` covers critical artifacts before gate transition.

`events.jsonl` must be append-only and hash-chained:
- monotonic `seq`
- unique `event_id`
- unique `idempotency_key`
- matching `prev_hash`
- matching `artifact_hash`
- actor field: `leader|team|reviewer|adapter`

Team-origin events are evidence only; they cannot complete Codex/Ultragoal goal.


## Portability Checklist

Before claiming this skill works in a target environment, map evidence:

- `doctor.mjs` or `doctor.py` output reports `manual`, `portable`, `workstation`, or `full`.
- `init-run.mjs` creates a run directory without OMX.
- `validate-run.mjs` or `validate_run.py` passes on the created run.
- If full mode is expected: `omx`, `tmux`, Codex/Claude hooks, and designslop audit are present.
- If live deploy is expected: Vercel or another deployment adapter is present and authenticated.
- If connectors are expected: Slack/mail/file/image access is explicitly authorized and privacy gate is active.

Do not describe missing runtime capability as working. Report degraded mode and next setup step.

## Output Shape

When reporting run status, use:

```markdown
## AIDP Demo Goal Status
- Run: <run-id>
- Stage: <stage>
- Goal state: <none|same|different>
- Gate: <pass|fail|blocked>
- Evidence: <paths>
- Blockers: <none/list>
- Next action: <one concrete action>
```

When producing final package summary, include:
- prototype/fallback evidence
- benchmark scorecard
- customer-problem-to-demo traceability
- demo script
- risks/limitations
- next-step roadmap
- completion audit path

## References

Read only when needed:
- `references/deployment-modes.md` for environment portability and rollout modes.
- `references/plan-summary.md` for design rationale and handoff shape.
- `templates/brief-template.md` for run intake.
- `templates/completion-audit-template.md` for final audit.
- `schemas/*.schema.json` for validation contracts.
