# Claude Code ↔ Codex Skill Gap Classification

Date: 2026-05-04
Machine: company MacBook Pro / current Codex session

## Snapshot After 1차 Migration

- Claude Code visible skills: 245
- Codex visible skills: 231
- Shared skill names: 231
- Claude-only skill names still not physically present in Codex: 14
- Codex-only skill names missing in Claude: 0
- Unresolved skill gap after policy allowlist/alias: 0

Important: the original 34 Claude-only entries resolved under `/Users/manager/wishket/claude-settings/...`, not the central `~/.config/claude-sync/codex/skills` surface. This pass promoted portable and guarded skills into the central Codex surface and left only intentional Claude-only or Codex-alias cases.

## Classification Legend

- `MIGRATED`: now copied/converted into Codex skills with Codex guardrails.
- `MIGRATED_WITH_GUARD`: now available in Codex, but the skill itself requires explicit approval or read-only default because it touches DB, env, external systems, or arbitrary execution.
- `ALLOWLIST_CLAUDE_ONLY`: intentionally remains Claude-only/runtime-specific.
- `DEDUP_OR_ALIAS`: Codex already has a nearby official/bundled skill/plugin; `sync-attest` resolves this by alias policy instead of duplicating.

| # | Skill | Final class | Codex status | Reason / Guardrail |
|---:|---|---|---|---|
| 1 | chrome-mcp-fix | ALLOWLIST_CLAUDE_ONLY | Policy allowlist | Chrome extension / Claude-in-Chrome MCP troubleshooting is Claude-specific. |
| 2 | db-patch | MIGRATED_WITH_GUARD | `codex/skills/db-patch` | DB mutation; explicit approval, blast-radius, backup/rollback, and no secret echoing required. |
| 3 | db-query | MIGRATED_WITH_GUARD | `codex/skills/db-query` | DB read; read-only posture, least-privilege query, and sensitive-data redaction required. |
| 4 | debug | DEDUP_OR_ALIAS | alias → `debugging-strategies` | Codex already has debugging/analyze flows. |
| 5 | develop | DEDUP_OR_ALIAS | alias → `worker` | Codex already has worker/executor/front/backend implementation surfaces. |
| 6 | dispatch-agents | ALLOWLIST_CLAUDE_ONLY | Policy allowlist | External Claude Code agent dispatch/runtime control is not Codex-native. |
| 7 | e2e-qa-report | MIGRATED | `codex/skills/e2e-qa-report` | Playwright screenshot QA report is compatible with Codex/browser tooling. |
| 8 | feature-develop | MIGRATED | `codex/skills/feature-develop` | Feature lifecycle is portable. |
| 9 | feature-error-fix | MIGRATED | `codex/skills/feature-error-fix` | RCA/fix/report lifecycle is portable. |
| 10 | feature-review | MIGRATED | `codex/skills/feature-review` | Planning/review/demo/PDF lifecycle is portable with Codex tooling substitutions. |
| 11 | git-commit-create | MIGRATED | `codex/skills/git-commit-create` | Git commit workflow is CLI-compatible. |
| 12 | git-extract-pr | MIGRATED | `codex/skills/git-extract-pr` | Worktree/partial PR workflow is CLI-compatible. |
| 13 | git-issue-create | MIGRATED | `codex/skills/git-issue-create` | GitHub issue workflow can use `gh`; external creation requires clear user intent. |
| 14 | git-pr-create | MIGRATED | `codex/skills/git-pr-create` | PR workflow can use `gh`; final publishing requires clear user intent. |
| 15 | git-workflow | MIGRATED | `codex/skills/git-workflow` | Integrated issue/sync/plan/commit workflow is portable. |
| 16 | html-presentation-deck | DEDUP_OR_ALIAS | alias → `presentations:Presentations` | Codex has Presentations plugin/skills. |
| 17 | init | ALLOWLIST_CLAUDE_ONLY | Policy allowlist | Generates Claude Code settings; Codex should use a separate init flow. |
| 18 | md-to-pdf | DEDUP_OR_ALIAS | alias → `pdf` | Codex already has PDF/document capabilities. |
| 19 | next-best-practices | DEDUP_OR_ALIAS | alias → `vercel:next-best-practices` | Codex has official Vercel/Next skills. |
| 20 | next-cache-components | DEDUP_OR_ALIAS | alias → `vercel:next-cache-components` | Codex has official Vercel Next Cache Components skill. |
| 21 | odoo-inspect | MIGRATED_WITH_GUARD | `codex/skills/odoo-inspect` | Odoo metadata inspection; read-only default and credential safeguards required. |
| 22 | odoo-query | MIGRATED_WITH_GUARD | `codex/skills/odoo-query` | Odoo data read; read-only default and redaction required. |
| 23 | odoo-run | MIGRATED_WITH_GUARD | `codex/skills/odoo-run` | Odoo method execution; explicit approval and rollback/dry-run guidance required. |
| 24 | pscan | MIGRATED | `codex/skills/pscan` | Project context scan is portable; `.claude` outputs must be mapped to Codex/project docs when needed. |
| 25 | refactor-comply | MIGRATED | `codex/skills/refactor-comply` | Rule-compliant refactor workflow is portable. |
| 26 | request-start | DEDUP_OR_ALIAS | alias → `documents:documents` | Document intake/PDF/image conversion overlaps with Codex Documents/PDF plugins. |
| 27 | setup-env | MIGRATED_WITH_GUARD | `codex/skills/setup-env` | 1Password/env writes; explicit approval, portability warning, and no secret echoing required. |
| 28 | slack-notify | ALLOWLIST_CLAUDE_ONLY | Policy allowlist | External Slack side effect; user preference requires explicit approval before any Slack notification. |
| 29 | supabase-postgres-best-practices | MIGRATED | `codex/skills/supabase-postgres-best-practices` | Read/write guidance skill; safe as documentation. |
| 30 | sync-issues | MIGRATED | `codex/skills/sync-issues` | GitHub issue/PR archive sync can use `gh`; repo/branch context required. |
| 31 | test | DEDUP_OR_ALIAS | alias → `webapp-testing` | Codex already has test/webapp-testing skills. |
| 32 | tmux-terminal-control | ALLOWLIST_CLAUDE_ONLY | Policy allowlist | Tmux pane orchestration is terminal-environment specific. |
| 33 | vercel-composition-patterns | DEDUP_OR_ALIAS | alias → `vercel:vercel-react-best-practices` | Codex has official Vercel React best-practices skill. |
| 34 | vitest | MIGRATED | `codex/skills/vitest` | Vitest guidance is portable. |

## Policy Artifacts

- Policy file: `config/skill-sync-policy.json`
- Attestation behavior: `bin/sync-attest.sh` now records raw gaps, policy allowlists, aliases, guarded skills available in Codex, and unresolved gaps separately.

## Current Meaning of “Same”

`Claude Code ↔ Codex same` now means:

1. Portable skills are physically available in both surfaces.
2. High-risk portable skills are physically available in both surfaces, but Codex copies contain explicit approval/redaction/rollback guardrails.
3. Claude-runtime-only skills remain Claude-only and are named in policy.
4. Duplicated official/plugin surfaces are resolved by alias policy rather than copied twice.
5. `sync-attest` fails only if a new unclassified gap appears, a policy file is missing, a link/hash breaks, or runtime doctor checks fail.
