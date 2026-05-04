# Claude Code ↔ Codex Skill Gap Classification

Date: 2026-05-04
Machine: company MacBook Pro / current Codex session

## Snapshot

- Claude Code visible skills: 245
- Codex visible skills: 211
- Shared skill names: 211
- Claude-only skills missing in Codex: 34
- Codex-only skills missing in Claude: 0

Important: all 34 Claude-only entries currently resolve under `/Users/manager/wishket/claude-settings/...`, not the central `~/.config/claude-sync/codex/skills` surface.

## Classification Legend

- `MIGRATE`: convert/copy into Codex skills with Codex-safe instructions.
- `MIGRATE_WITH_GUARD`: useful in Codex but must require explicit user approval or read-only default because it touches DB, env, Slack, external systems, or arbitrary execution.
- `ALLOWLIST_CLAUDE_ONLY`: should remain Claude-only, or is tied to Claude-specific runtime/MCP/hook behavior.
- `DEDUP_OR_ALIAS`: Codex already has a nearby official/bundled skill/plugin; prefer alias/mapping or allowlist instead of duplicating unless exact name parity is required.

| # | Skill | Recommended class | Reason | Next action |
|---:|---|---|---|---|
| 1 | chrome-mcp-fix | ALLOWLIST_CLAUDE_ONLY | Chrome extension / Claude-in-Chrome MCP troubleshooting is Claude-specific. | Add to sync-attest allowlist. |
| 2 | db-patch | MIGRATE_WITH_GUARD | DB mutation can be useful, but must require explicit approval and transaction/backup guidance. | Convert only with approval-first policy. |
| 3 | db-query | MIGRATE_WITH_GUARD | DB read-only inspection can be useful, but may expose sensitive data. | Convert with read-only + redaction guidance. |
| 4 | debug | DEDUP_OR_ALIAS | Codex already has debugging-strategies/analyze style skills; name parity optional. | Prefer alias to existing debugging flow, or migrate if exact slash workflow needed. |
| 5 | develop | DEDUP_OR_ALIAS | Codex already has executor/frontend/backend pattern skills; generic develop overlaps heavily. | Alias to Codex implementation workflow. |
| 6 | dispatch-agents | ALLOWLIST_CLAUDE_ONLY | Describes external Claude Code agents/background dispatch, not Codex native subagent contract. | Keep Claude-only unless rewritten from scratch for Codex. |
| 7 | e2e-qa-report | MIGRATE | Playwright screenshot QA report is compatible with Codex/browser tooling. | Convert to Codex skill. |
| 8 | feature-develop | MIGRATE | High-level feature lifecycle can work in both harnesses. | Convert with Codex wording and no Claude-only assumptions. |
| 9 | feature-error-fix | MIGRATE | RCA/fix/report lifecycle is portable. | Convert to Codex skill. |
| 10 | feature-review | MIGRATE | Planning/review/PDF design lifecycle is portable if PDF tooling is optional. | Convert; replace Claude-specific tools with generic/Codex tools. |
| 11 | git-commit-create | MIGRATE | Git commit workflow is useful and CLI-compatible. | Convert; keep gh/native CLI preference. |
| 12 | git-extract-pr | MIGRATE | Worktree/partial PR workflow is CLI-compatible. | Convert; emphasize dirty-tree safety. |
| 13 | git-issue-create | MIGRATE | GitHub issue workflow can use gh CLI. | Convert; require user approval before publishing. |
| 14 | git-pr-create | MIGRATE | PR workflow can use gh CLI. | Convert; require final user review before creation if needed. |
| 15 | git-workflow | MIGRATE | Integrated issue/sync/plan/commit workflow is portable. | Convert after checking dependencies on local archives. |
| 16 | html-presentation-deck | DEDUP_OR_ALIAS | Codex has Presentations plugin/skills; exact HTML deck workflow may still be useful. | Prefer alias to Presentations unless exact HTML deck output is required. |
| 17 | init | ALLOWLIST_CLAUDE_ONLY | Generates Claude Code settings (`CLAUDE.md`, `.claude/`, scripts). | Keep Claude-only; create separate Codex init if needed. |
| 18 | md-to-pdf | DEDUP_OR_ALIAS | Codex already has pdf/documents capabilities. | Alias to existing pdf skill; migrate only if Chrome-specific renderer is required. |
| 19 | next-best-practices | DEDUP_OR_ALIAS | Codex has Vercel/Next official skills and nextjs-app-router-patterns. | Prefer official Vercel Next skill; alias if exact name parity required. |
| 20 | next-cache-components | DEDUP_OR_ALIAS | Codex has Vercel Next Cache Components skill. | Alias to official Vercel skill. |
| 21 | odoo-inspect | MIGRATE_WITH_GUARD | Odoo schema inspection can be useful but system-specific. | Convert with read-only default and credential safeguards. |
| 22 | odoo-query | MIGRATE_WITH_GUARD | Odoo data query can expose sensitive data. | Convert with read-only + redaction + approval guidance. |
| 23 | odoo-run | MIGRATE_WITH_GUARD | Arbitrary Odoo method execution is high-risk. | Convert only with explicit approval gates or allowlist as Claude-only. |
| 24 | pscan | MIGRATE | Project context scan is portable and useful in Codex. | Convert to Codex skill. |
| 25 | refactor-comply | MIGRATE | Rule-compliant refactor workflow is portable. | Convert; map `.claude/references` to project docs/AGENTS.md where needed. |
| 26 | request-start | DEDUP_OR_ALIAS | Document intake/PDF/image conversion overlaps with Documents/PDF plugins; may be company-specific. | Alias to document workflow or migrate if the receipt format is important. |
| 27 | setup-env | MIGRATE_WITH_GUARD | 1Password/env writes are sensitive and machine-specific. | Convert with explicit approval, no secret echoing, and portability warnings. |
| 28 | slack-notify | ALLOWLIST_CLAUDE_ONLY | External Slack side effects conflict with user preference: no Slack without explicit approval. | Keep Claude-only or convert as disabled/manual-only. |
| 29 | supabase-postgres-best-practices | MIGRATE | Read/write guidance skill; safe and portable as documentation. | Convert to Codex skill. |
| 30 | sync-issues | MIGRATE | GitHub issue/PR archive sync can use gh CLI. | Convert; require clear repo and branch context. |
| 31 | test | DEDUP_OR_ALIAS | Codex has many testing skills and webapp-testing; generic test overlaps. | Alias to test/webapp-testing, or migrate if this exact workflow is important. |
| 32 | tmux-terminal-control | ALLOWLIST_CLAUDE_ONLY | Tmux pane/session orchestration is terminal-environment-specific and may not fit Codex API harness. | Keep Claude-only unless user explicitly wants tmux parity. |
| 33 | vercel-composition-patterns | DEDUP_OR_ALIAS | Codex has Vercel React best-practices and frontend skills. | Alias to official Vercel React skill. |
| 34 | vitest | MIGRATE | Vitest guidance is portable and useful. | Convert to Codex skill. |

## Recommended Rollout

1. First migrate low-risk portable skills:
   - e2e-qa-report, feature-develop, feature-error-fix, feature-review, git-* workflows, pscan, refactor-comply, supabase-postgres-best-practices, sync-issues, vitest.
2. Add allowlist for clearly Claude-only skills:
   - chrome-mcp-fix, dispatch-agents, init, slack-notify, tmux-terminal-control.
3. Add alias/dedup mapping for overlaps:
   - debug, develop, html-presentation-deck, md-to-pdf, next-best-practices, next-cache-components, request-start, test, vercel-composition-patterns.
4. Only then handle guarded integrations:
   - db-patch, db-query, odoo-inspect, odoo-query, odoo-run, setup-env.

