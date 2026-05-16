#!/usr/bin/env bash
# codex-bridge.sh - keep Claude Code and Codex shared surfaces in sync.
set -euo pipefail

SSOT="${AGENT_HARNESS_BASELINE_HOME:-$HOME/.config/agent-harness-baseline}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
CODEX_SKILLS="${CODEX_SKILLS:-$SSOT/codex/skills}"
SHARED_SKILLS="${SHARED_SKILLS:-$CODEX_HOME/skills}"

quiet=0
validate=0
push=0
link=1
sync_memories_enabled=1

usage() {
  cat <<'EOF'
Usage: codex-bridge.sh [--quiet] [--validate] [--push] [--no-link] [--no-memories]

Synchronizes:
  - Claude slash commands -> Codex skills in ~/.codex/skills
  - malformed Claude setup-notify-hooks skill -> valid Codex skill
  - Claude project memories -> Codex memories (unless --no-memories)
  - Claude subagents -> Codex custom agents
  - ~/AGENTS.md global instructions
  - Codex agents/hooks/skills/memories through ~/.config/agent-harness-baseline/codex

  Secret-bearing config.toml is intentionally not committed. Use 1Password/env
for secrets and keep only non-secret shared behavior in this bridge.
EOF
}

log() {
  (( quiet == 1 )) && return 0
  printf '%s\n' "$*"
}

while (($#)); do
  case "$1" in
    --quiet) quiet=1 ;;
    --validate) validate=1 ;;
    --push) push=1 ;;
    --no-link) link=0 ;;
    --no-memories) sync_memories_enabled=0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[[ -d "$SSOT" ]] || { echo "Missing SSOT: $SSOT" >&2; exit 1; }
mkdir -p "$CODEX_HOME" "$SSOT/codex/agents" "$SSOT/codex/hooks" "$SSOT/codex/skills" "$SSOT/codex/memories"
if (( link == 1 )) && [[ -x "$SSOT/bin/link-design.sh" ]]; then
  "$SSOT/bin/link-design.sh" >/dev/null 2>&1 || true
fi

copy_into_empty_dir() {
  local src="$1" dst="$2"
  [[ -d "$src" ]] || return 0
  mkdir -p "$dst"
  if [[ -z "$(find "$dst" -mindepth 1 -maxdepth 1 2>/dev/null | head -1)" ]]; then
    rsync -a --exclude '.git' "$src"/ "$dst"/
  fi
}

backup_path() {
  local path="$1"
  [[ -e "$path" || -L "$path" ]] || return 0
  local backup="$path.bak.$(date +%s)"
  mv "$path" "$backup"
  log "Backed up $path -> $backup"
}

link_dir() {
  local src="$1" dst="$2"
  mkdir -p "$src"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    return 0
  fi
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    copy_into_empty_dir "$dst" "$src"
    backup_path "$dst"
  elif [[ -L "$dst" ]]; then
    rm -f "$dst"
  fi
  rm -rf "$dst"
  ln -s "$src" "$dst"
  log "Linked $dst -> $src"
}

link_file() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$src")" "$(dirname "$dst")"
  if [[ ! -f "$src" && -f "$dst" ]]; then
    cp "$dst" "$src"
  fi
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    return 0
  fi
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    backup_path "$dst"
  elif [[ -L "$dst" ]]; then
    rm -f "$dst"
  fi
  rm -f "$dst"
  ln -s "$src" "$dst"
  log "Linked $dst -> $src"
}

merge_omx_hooks_into_live_file() {
  local hooks_file="$1"
  command -v omx >/dev/null 2>&1 || return 0
  command -v node >/dev/null 2>&1 || return 0

  local omx_real pkg_root
  omx_real="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$(command -v omx)" 2>/dev/null || true)"
  [[ -n "$omx_real" ]] || return 0
  pkg_root="$(cd "$(dirname "$omx_real")/../.." 2>/dev/null && pwd -P || true)"
  [[ -f "$pkg_root/dist/config/codex-hooks.js" ]] || return 0

  HOOKS_FILE="$hooks_file" OMX_PACKAGE_ROOT="$pkg_root" node --input-type=module <<'NODE' >/dev/null 2>&1 || true
import { readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
const hooksFile = process.env.HOOKS_FILE;
const pkgRoot = process.env.OMX_PACKAGE_ROOT;
if (!hooksFile || !pkgRoot) process.exit(0);
const { mergeManagedCodexHooksConfig } = await import(`${pkgRoot}/dist/config/codex-hooks.js`);
const before = existsSync(hooksFile) ? await readFile(hooksFile, 'utf8') : undefined;
await writeFile(hooksFile, mergeManagedCodexHooksConfig(before, pkgRoot));
NODE
}

ensure_codex_links() {
  copy_into_empty_dir "$CODEX_HOME/agents" "$SSOT/codex/agents"
  copy_into_empty_dir "$CODEX_HOME/hooks" "$SSOT/codex/hooks"
  copy_into_empty_dir "$CODEX_HOME/skills" "$SSOT/codex/skills"
  copy_into_empty_dir "$CODEX_HOME/memories" "$SSOT/codex/memories"

  if [[ ! -f "$SSOT/codex/hooks.json" && -f "$CODEX_HOME/hooks.json" ]]; then
    cp "$CODEX_HOME/hooks.json" "$SSOT/codex/hooks.json"
  fi

  link_dir "$SSOT/codex/agents" "$CODEX_HOME/agents"
  link_dir "$SSOT/codex/hooks" "$CODEX_HOME/hooks"
  link_dir "$SSOT/codex/skills" "$CODEX_HOME/skills"
  link_dir "$SSOT/codex/memories" "$CODEX_HOME/memories"

  # Codex may rewrite hooks.json as a regular file while loading hooks.
  # Keep the SSOT copy authoritative, then merge machine-local OMX hook coverage
  # so the checked-in SSOT remains portable across Homebrew/npm install paths.
  cp "$SSOT/codex/hooks.json" "$CODEX_HOME/hooks.json"
  merge_omx_hooks_into_live_file "$CODEX_HOME/hooks.json"
}

frontmatter_description() {
  local file="$1"
  local heading
  heading=$(sed -n 's/^# \{1,\}//p' "$file" | head -1)
  if [[ -n "$heading" ]]; then
    printf 'Converted from Claude slash command: %s' "$heading"
  else
    printf 'Converted from Claude slash command.'
  fi
}

display_source_path() {
  local path="$1"
  if [[ "$path" == "$SSOT/"* ]]; then
    printf '$AGENT_HARNESS_BASELINE_HOME/%s' "${path#"$SSOT"/}"
  else
    printf '%s' "$path"
  fi
}

sync_commands_to_skills() {
  local commands_dir="$SSOT/claude/commands"
  [[ -d "$commands_dir" ]] || return 0

  local cmd name target desc
  for cmd in "$commands_dir"/*.md; do
    [[ -f "$cmd" ]] || continue
    name="$(basename "$cmd" .md)"
    target="$SHARED_SKILLS/$name/SKILL.md"
    if [[ -f "$target" ]] && ! grep -q 'AUTO-GENERATED by codex-bridge.sh' "$target"; then
      log "Skip Claude command skill '$name' because a non-generated Codex skill already exists"
      continue
    fi
    mkdir -p "$(dirname "$target")"
    desc="$(frontmatter_description "$cmd")"
    {
      printf '%s\n' '---'
      printf 'name: %s\n' "$name"
      printf 'description: |-\n'
      printf '  %s\n' "$desc"
      printf '%s\n\n' '---'
      printf '<!-- AUTO-GENERATED by codex-bridge.sh from %s. Do not edit this generated copy. -->\n\n' "$(display_source_path "$cmd")"
      cat "$cmd"
    } > "$target.tmp"
    mv "$target.tmp" "$target"
  done
  log "Synced Claude commands into Codex skills"
}

sync_setup_notify_skill() {
  local src="$SSOT/claude/skills/setup-notify-hooks/SKILL.md"
  local target="$SHARED_SKILLS/setup-notify-hooks/SKILL.md"
  [[ -f "$src" ]] || return 0
  # After cross-tool skill mirroring, Claude may expose this skill as a symlink
  # back to Codex. Avoid regenerating the target from itself, which would
  # duplicate the generated wrapper on every bridge run.
  if [[ "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$src")" == "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$target" 2>/dev/null || true)" ]]; then
    log "Skip setup-notify-hooks because Claude source resolves to Codex target"
    return 0
  fi
  if [[ -f "$target" ]] && ! grep -q 'AUTO-GENERATED by codex-bridge.sh' "$target"; then
    log "Skip setup-notify-hooks because a non-generated Codex skill already exists"
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  {
    printf '%s\n' '---'
    printf '%s\n' 'name: setup-notify-hooks'
    sed -n '/^---$/,/^---$/p' "$src" | sed '1d;$d' | grep -v '^name:' || true
    printf '%s\n\n' '---'
    printf '<!-- AUTO-GENERATED by codex-bridge.sh from %s with Codex-compatible name metadata. -->\n\n' "$(display_source_path "$src")"
    sed '1,/^---$/d' "$src" | sed '1,/^---$/d'
  } > "$target.tmp"
  mv "$target.tmp" "$target"
  log "Synced setup-notify-hooks as valid Codex skill"
}

sync_memories() {
  local mem_dir="$SSOT/codex/memories"
  mkdir -p "$mem_dir"

  local raw_tmp="$mem_dir/raw_memories.md.tmp"
  local handbook_tmp="$mem_dir/MEMORY.md.tmp"
  local summary_tmp="$mem_dir/memory_summary.md.tmp"

  {
    printf '# Raw Memories\n\n'
    printf 'Generated by `codex-bridge.sh` from Claude project memory files on %s.\n\n' "$(date +%F)"
    local found=0
    while IFS= read -r index; do
      found=1
      local dir project
      dir="$(dirname "$index")"
      project="$(basename "$(dirname "$dir")")"
      printf '## Source Index: `%s`\n\n' "$index"
      cat "$index"
      printf '\n\n'
      local file
      while IFS= read -r file; do
        printf '### `%s`\n\n' "$(basename "$file")"
        cat "$file"
        printf '\n\n'
      done < <(find "$dir" -maxdepth 1 -type f -name '*.md' ! -name 'MEMORY.md' | sort)
      printf '\n'
    done < <(find "$CLAUDE_HOME/projects" -path '*/memory/MEMORY.md' -type f 2>/dev/null | sort)
    if (( found == 0 )); then
      printf 'No Claude project memories found at import time.\n'
    fi
  } > "$raw_tmp"

  {
    printf '# Memory Handbook\n\n'
    printf 'This directory is shared through `~/.config/agent-harness-baseline/codex/memories` and linked to `~/.codex/memories`.\n\n'
    printf 'Generated from Claude project memory indexes by `codex-bridge.sh`.\n\n'
    printf '## Source Indexes\n\n'
    find "$CLAUDE_HOME/projects" -path '*/memory/MEMORY.md' -type f 2>/dev/null | sort | sed 's/^/- `/' | sed 's/$/`/' || true
  } > "$handbook_tmp"

  {
    printf '## User Profile\n\n'
    printf 'Use imported memory as evidence. Do not invent durable preferences beyond the files listed below.\n\n'
    printf '## Shared Preferences And Project Facts\n\n'
    printf -- '- Flag machine-specific absolute paths and usernames as portability risks.\n'
    printf -- '- Prefer `gh` CLI first for GitHub work; prefer native CLI before MCP for general work.\n'
    printf -- '- Do not send Slack or external notification messages without explicit approval.\n'
    printf -- '- Treat AIDP voice2patch as an extension of `aidp-os`, not a greenfield rebuild.\n'
    printf -- '- Coordinate OMC team workers with explicit task updates and mailbox messages; do not rely on naive prompt splitting.\n\n'
    printf '## Imported Files\n\n'
    find "$CLAUDE_HOME/projects" -path '*/memory/*.md' -type f 2>/dev/null | sort | sed 's/^/- `/' | sed 's/$/`/' || true
  } > "$summary_tmp"

  mv "$raw_tmp" "$mem_dir/raw_memories.md"
  mv "$handbook_tmp" "$mem_dir/MEMORY.md"
  mv "$summary_tmp" "$mem_dir/memory_summary.md"
  log "Synced Claude memories into Codex memories"
}

sync_subagents() {
  local migrator="$CODEX_HOME/skills/migrate-to-codex/scripts/migrate-to-codex.py"
  [[ -f "$migrator" ]] || return 0
  local py="python3"
  if command -v python3.13 >/dev/null 2>&1; then
    py="python3.13"
  elif command -v python3.11 >/dev/null 2>&1; then
    py="python3.11"
  fi
  "$py" "$migrator" --source "$CLAUDE_HOME/" --target "$CODEX_HOME/" --subagents >/dev/null
  log "Synced Claude subagents into Codex agents"
}

rebuild_agents_md() {
  if [[ -x "$SSOT/bin/rebuild-agents-md.sh" ]]; then
    "$SSOT/bin/rebuild-agents-md.sh" --quiet >/dev/null 2>&1 || true
    log "Rebuilt ~/AGENTS.md"
  fi
}

validate_codex() {
  local migrator="$CODEX_HOME/skills/migrate-to-codex/scripts/migrate-to-codex.py"
  [[ -f "$migrator" ]] || return 0
  local py="python3"
  if command -v python3.13 >/dev/null 2>&1; then
    py="python3.13"
  elif command -v python3.11 >/dev/null 2>&1; then
    py="python3.11"
  fi
  "$py" "$migrator" --validate-target "$CODEX_HOME/"
}

(( link == 1 )) && ensure_codex_links
sync_commands_to_skills
sync_setup_notify_skill
if (( sync_memories_enabled == 1 )); then
  sync_memories
fi
sync_subagents
rebuild_agents_md
merge_omx_hooks_into_live_file "$CODEX_HOME/hooks.json"

if (( validate == 1 )); then
  validate_codex
fi

if (( push == 1 )); then
  "$SSOT/bin/sync.sh" --immediate >/dev/null 2>&1 || true
  log "Committed/pushed SSOT changes when possible"
fi

log "Codex bridge sync complete"
