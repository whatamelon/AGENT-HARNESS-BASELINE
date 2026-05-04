#!/usr/bin/env bash
# Print shared design context entrypoints and discover project-local design docs.
set -euo pipefail

SSOT="${CLAUDE_SYNC_HOME:-$HOME/.config/claude-sync}"
GLOBAL_DESIGN="$SSOT/design/DESIGN.md"
GLOBAL_GETDESIGN="$SSOT/design/getdesign.md"

printf 'Shared design context\n'
printf '=====================\n\n'
printf 'Global DESIGN.md:    %s\n' "$GLOBAL_DESIGN"
printf 'Global getdesign.md: %s\n' "$GLOBAL_GETDESIGN"
printf 'Home entrypoints:\n'
printf '  - %s\n' "$HOME/DESIGN.md"
printf '  - %s\n' "$HOME/getdesign.md"
printf 'Claude entrypoints:\n'
printf '  - %s\n' "$HOME/.claude/DESIGN.md"
printf '  - %s\n' "$HOME/.claude/getdesign.md"
printf 'Codex entrypoints:\n'
printf '  - %s\n' "$HOME/.codex/DESIGN.md"
printf '  - %s\n\n' "$HOME/.codex/getdesign.md"

printf 'Project-local design files from cwd upward:\n'
found=0
seen_reals=""
GLOBAL_DESIGN_REAL="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$GLOBAL_DESIGN")"
GLOBAL_GETDESIGN_REAL="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$GLOBAL_GETDESIGN")"
print_candidate() {
  local file="$1" real_file
  [[ -f "$file" ]] || return 0
  real_file="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$file")"
  [[ "$real_file" == "$GLOBAL_DESIGN_REAL" || "$real_file" == "$GLOBAL_GETDESIGN_REAL" ]] && return 0
  case "
$seen_reals
" in
    *"
$real_file
"*) return 0 ;;
  esac
  seen_reals="${seen_reals}${real_file}
"
  printf '  - %s\n' "$file"
  found=1
}

current="$PWD"
while :; do
  for name in DESIGN.md design.md Design.md getdesign.md GETDESIGN.md; do
    print_candidate "$current/$name"
  done
  for pattern in "$current"/docs/[Dd]esign*.md "$current"/docs/*design*.md "$current"/design/[Dd]esign*.md; do
    print_candidate "$pattern"
  done
  [[ "$current" == "$HOME" || "$current" == "/" ]] && break
  current="$(dirname "$current")"
done
(( found == 1 )) || printf '  (none found)\n'

printf '\nRecommended read order:\n'
printf '  1. User request\n'
printf '  2. Nearest project-local DESIGN/design docs above\n'
printf '  3. %s\n' "$GLOBAL_GETDESIGN"
printf '  4. %s\n' "$GLOBAL_DESIGN"
