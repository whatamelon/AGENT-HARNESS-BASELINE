---
name: aidp-evidence-dossier
description: "AIDP/FDE evidence intelligence skill. Use whenever user asks to analyze Slack, Gmail, Google Drive, Calendar, files, images, GitHub, RFPs, meeting notes, or customer context to prepare a proposal/demo brief. Builds an evidence dossier with purity, recency, authority, contradiction, context fit, and demo-usefulness scoring, then outputs a recommended brief for aidp-demo-goal."
---

# AIDP Evidence Dossier

Use this skill before `aidp-demo-goal` when customer context must be inferred from existing evidence rather than manually supplied brief.

## Purpose

Turn messy customer/project evidence into a decision-ready dossier:

```text
Slack / Gmail / Drive / Calendar / files / images / GitHub / RFP
→ evidence source index
→ purity + recency + authority + contradiction + context scoring
→ current context narrative
→ demo opportunities
→ recommended brief for aidp-demo-goal
```

## Core Contract

- Evidence first, assumption second.
- Do not send Slack, email, Google Chat, or external messages without explicit user approval.
- Prefer local authenticated tools already present on the machine: Slack MCP, `gws`, `gh`, local files.
- Search only within user-provided customer/project scope. Do not broaden to unrelated customers without reason.
- Separate confirmed facts, inferred context, stale evidence, contradictions, and unknowns.
- Recent evidence does not always win; evidence type controls freshness decay.
- Older signed/RFP/security evidence can outrank newer casual chat.
- Every recommended brief claim must link to evidence id or be marked as inference.
- If connector auth is missing/invalid, record connector gap and continue from available/local evidence.

## Artifacts

Create one dossier directory:

```text
.omx/evidence/<customer-or-project-slug>/
  intake.md
  connector-report.json
  source-index.json
  evidence-graph.json
  evidence-dossier.md
  recommended-brief.md
  open-questions.md
  raw/
    slack/
    gmail/
    drive/
    calendar/
    github/
    files/
    images/
```

## Environment and Connector Doctor

Run doctor first:

```sh
node <skill-dir>/scripts/doctor.mjs
# Python fallback:
python3 <skill-dir>/scripts/doctor.py
```

Connector meanings:

| Source | Tool | Use |
|---|---|---|
| Slack | Slack MCP tools | channel history, threads, search, DMs when authorized |
| Gmail | `gws gmail` | email threads and customer comms |
| Drive | `gws drive` | RFPs, docs, spreadsheets, decks, attachments |
| Calendar | `gws calendar` | meeting recency, attendees, agenda timing |
| Docs/Sheets/Slides | `gws docs/sheets/slides` | structured customer artifacts |
| GitHub | `gh` | issues, PRs, repos, discussions, technical context |
| Local files/images | filesystem + vision agent when needed | PDFs, docs, screenshots, reference images |

## Workflow

### 1. Scope Intake

Capture:
- customer/project name
- time window, default last 180 days
- channels/accounts/repos/files to include
- forbidden scopes
- meeting date and proposal objective if known
- data sensitivity and sharing constraints

Create initial dossier directory:

```sh
node <skill-dir>/scripts/init-dossier.mjs --slug <customer-project> --customer "<name>" --objective "<proposal objective>"
```

### 2. Connector Inventory

Record available connectors in `connector-report.json`.

If this chat has MCP Slack tools available, use them for read-only Slack evidence. If shell has `gws`, use it for Gmail/Drive/Calendar evidence. If shell has `gh`, run `gh auth status` before relying on GitHub.

Never hide auth failure. Record it.

### 3. Evidence Collection

Collect only relevant evidence. Save raw extracts under `raw/<source>/` and register each item in `source-index.json`.

Recommended source item shape:

```json
{
  "id": "ev_001",
  "source": "slack|gmail|drive|calendar|github|file|image|web|manual",
  "title": "string",
  "uri": "string or path",
  "timestamp": "ISO-8601|null",
  "speaker_role": "customer_decision_maker|customer_operator|customer_engineer|internal_sales|internal_engineer|system|unknown",
  "directness": "direct|relayed|inferred",
  "evidence_type": "rfp|signed_doc|customer_statement|meeting_note|email|slack_thread|calendar_event|technical_artifact|screenshot|internal_note|github_issue|github_pr|other",
  "summary": "short factual summary",
  "claims": ["atomic claim 1"],
  "tags": ["pain", "constraint", "timeline", "demo", "security"]
}
```

### 4. Score Evidence

Run scoring after `source-index.json` has items:

```sh
node <skill-dir>/scripts/score-evidence.mjs .omx/evidence/<slug>/source-index.json > .omx/evidence/<slug>/evidence-graph.json
```

Generate deterministic dossier/brief draft:

```sh
node <skill-dir>/scripts/synthesize-dossier.mjs .omx/evidence/<slug>
```

Validate artifacts:

```sh
node <skill-dir>/scripts/validate-dossier.mjs .omx/evidence/<slug>
# Python fallback:
python3 <skill-dir>/scripts/validate_dossier.py .omx/evidence/<slug>
```

Scores:
- `purity`: direct, authoritative, specific, repeated, artifact-backed, low contradiction.
- `recency`: type-aware freshness, not simple newest-wins.
- `authority`: speaker/source decision weight.
- `context_fit`: fits current proposal objective and recent thread.
- `demo_usefulness`: can become visible demo flow inside time/boundaries.
- `overall`: weighted decision score.

### 5. Resolve Context and Contradictions

Build `evidence-dossier.md` using:
- high-purity facts
- current context timeline
- stale/time-decayed evidence
- contradictions and resolution rule
- demo opportunities
- critical unknowns
- recommended brief

Contradiction priority default:
1. current customer decision or RFP
2. signed/official artifact
3. customer decision-maker direct statement
4. repeated customer pain
5. technical artifact/current repo reality
6. internal interpretation
7. old notes or brainstorming

Exceptions:
- security/legal/signed constraints decay slowly.
- casual new Slack messages do not override official docs by themselves.

### 6. Generate Recommended Brief

`recommended-brief.md` must include:
- customer/problem/industry
- proposal objective and meeting context
- current best interpretation
- demo wow moment
- target users and jobs
- constraints and data policy
- available assets
- benchmark/reference candidates
- proposed demo flow
- success criteria
- evidence map per claim
- assumptions and open questions

Then hand to `aidp-demo-goal`:

```text
Use aidp-demo-goal with .omx/evidence/<slug>/recommended-brief.md
```

## Freshness Policy

Default half-life by evidence type:

| Type | Half-life | Notes |
|---|---:|---|
| schedule/timeline | 14 days | meeting schedules change fast |
| budget/procurement | 30 days | verify before proposal |
| active requirement | 60 days | newer RFP/customer decision can override |
| technical stack | 90 days | repo/current files may override |
| customer pain | 180 days | stable unless new direction appears |
| security/legal/signed | 365 days | stale slowly; official docs strong |
| brainstorming/internal note | 30 days | low authority unless confirmed |

## Output Format

Final response should summarize:

```markdown
## Evidence Dossier Result
- Dossier: .omx/evidence/<slug>/evidence-dossier.md
- Recommended brief: .omx/evidence/<slug>/recommended-brief.md
- Sources indexed: <n>
- High-purity facts: <n>
- Stale/low-purity items: <n>
- Contradictions: <n>
- Critical unknowns: <n>
- Next: run aidp-demo-goal with recommended brief
```

## Completion Checklist

Do not claim dossier complete unless:
- connector availability checked or intentionally skipped
- `source-index.json` exists and validates
- `evidence-graph.json` exists and validates
- `evidence-dossier.md` exists with high-purity facts, stale evidence, contradictions, demo opportunities, unknowns
- `recommended-brief.md` exists and maps claims to evidence ids/inferences
- auth gaps are documented
- no external messages were sent without approval

## References

Read when needed:
- `references/scoring-model.md`
- `templates/evidence-dossier-template.md`
- `templates/recommended-brief-template.md`
- `schemas/source-index.schema.json`
- `schemas/evidence-graph.schema.json`
