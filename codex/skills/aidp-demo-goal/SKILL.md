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

Create `.omx/goal-runs/<run-id>/` and seed:
- `brief.md` from `templates/brief-template.md`
- `run.json` matching `schemas/run.schema.json`
- `lock.json` matching state contract below
- empty `events.jsonl`
- initial `stage-gates.json`

Run schema validation with:

```sh
node <skill-dir>/scripts/validate-run.mjs .omx/goal-runs/<run-id>
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
- Team terminal summary has no critical failed lane
- benchmark score meets threshold or approved delta is documented
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
- `references/plan-summary.md` for design rationale and handoff shape.
- `templates/brief-template.md` for run intake.
- `templates/completion-audit-template.md` for final audit.
- `schemas/*.schema.json` for validation contracts.
