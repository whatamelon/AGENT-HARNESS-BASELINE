# AIDP Demo Goal Plan Summary

Origin: RALPLAN artifacts from the local `.omx/plans/` planning workspace for enterprise `/goal` plugin.

Core decision: build skill-first harness as thin policy layer over Ultragoal and Team.

State split:
- AIDP demo goal skill owns proposal artifacts, stage gates, benchmark/evaluator policy, deployment/demo package, completion audit.
- Ultragoal owns durable goal truth and checkpoint ledger.
- Team owns worker runtime and execution evidence.
- Leader owns transitions, snapshots, checkpoints, and final completion.

Key risks:
- split-brain state between run dir and Ultragoal
- worker goal-state mutation
- impressive but wrong prototype
- missing deploy/demo evidence
- stale long-running Team state

Mitigations:
- active goal reconciliation before mutation
- atomic lock/event log with leader epoch and hash chain
- benchmark before design/dev
- non-overridable security/deployment/completion gates
- Team evidence-only boundary
- final quality gate before `update_goal`
