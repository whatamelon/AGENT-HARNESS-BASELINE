# Shared Design Context

`DESIGN.md` and `getdesign.md` are shared Claude Code ↔ Codex design entrypoints.

## Canonical source

- `~/.config/claude-sync/design/DESIGN.md`
- `~/.config/claude-sync/design/getdesign.md`

These are linked to:

- `~/DESIGN.md`, `~/getdesign.md`
- `~/.claude/DESIGN.md`, `~/.claude/getdesign.md`
- `~/.codex/DESIGN.md`, `~/.codex/getdesign.md`

## Rule

Before UI/UX/product/visual work, load `getdesign.md`, then `DESIGN.md`, then project-local design docs. Summarize active design constraints and validate visually when possible.

Do not create machine-local divergent copies. Update the canonical files in `~/.config/claude-sync/design/` and run `bash ~/.config/claude-sync/bin/sync-attest.sh` to certify sync.
