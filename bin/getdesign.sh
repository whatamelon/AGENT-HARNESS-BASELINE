#!/usr/bin/env bash
# Shared DESIGN.md helper.
# - No args: print shared design context and discover project-local design docs.
# - init/copy: copy the shared DESIGN.md into the current project root.
# - add <slug>: run getdesign.md catalog installer for a brand inspiration.
set -euo pipefail

SSOT="${CLAUDE_SYNC_HOME:-$HOME/.config/claude-sync}"
GLOBAL_DESIGN="$SSOT/design/DESIGN.md"
GLOBAL_GETDESIGN="$SSOT/design/getdesign.md"
GLOBAL_HARNESS_DIR="$SSOT/design/harness"

usage() {
  cat <<'EOF_USAGE'
Usage:
  getdesign                 Show active design context and project-local docs
  getdesign show            Same as no args
  getdesign init [--force]  Copy shared DESIGN.md/getdesign.md into current project
  getdesign copy [--force]  Alias for init
  getdesign init-harness [--force]
                            Copy shared visual quality harness into current project
  getdesign init-mobile-harness [--force] [--path <file>]
                            Copy Expo/RN iPhone preview harness into current project
  getdesign add <slug>      Run: npx getdesign@latest add <slug>
  getdesign doctor          Verify shared DESIGN.md entrypoint links

Examples:
  getdesign
  getdesign init
  getdesign init-harness
  getdesign init-mobile-harness --path packages/mobile-ui/src/design-harness.tsx
  getdesign add linear.app
  getdesign add cursor
EOF_USAGE
}

real_path() {
  python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"
}

show_context() {
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
  GLOBAL_DESIGN_REAL="$(real_path "$GLOBAL_DESIGN")"
  GLOBAL_GETDESIGN_REAL="$(real_path "$GLOBAL_GETDESIGN")"
  print_candidate() {
    local file="$1" real_file
    [[ -f "$file" ]] || return 0
    real_file="$(real_path "$file")"
    [[ "$real_file" == "$GLOBAL_DESIGN_REAL" || "$real_file" == "$GLOBAL_GETDESIGN_REAL" ]] && return 0
    case "\n$seen_reals\n" in
      *"\n$real_file\n"*) return 0 ;;
    esac
    seen_reals="${seen_reals}${real_file}\n"
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
}

init_project() {
  local force=0
  while (($#)); do
    case "$1" in
      --force) force=1 ;;
      *) echo "Unknown init argument: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
  done
  [[ -f "$GLOBAL_DESIGN" ]] || { echo "Missing $GLOBAL_DESIGN" >&2; exit 1; }
  [[ -f "$GLOBAL_GETDESIGN" ]] || { echo "Missing $GLOBAL_GETDESIGN" >&2; exit 1; }

  for file in DESIGN.md getdesign.md; do
    src="$SSOT/design/$file"
    dst="$PWD/$file"
    if [[ -e "$dst" && $force -ne 1 ]]; then
      echo "skip: $dst exists (use --force to overwrite)"
      continue
    fi
    cp "$src" "$dst"
    echo "copied: $dst"
  done
  echo "Project DESIGN.md is now local to this repo. Commit it with the project if desired."
}

init_harness() {
  local force=0
  while (($#)); do
    case "$1" in
      --force) force=1 ;;
      *) echo "Unknown init-harness argument: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
  done
  [[ -f "$GLOBAL_HARNESS_DIR/visual-check.mjs" ]] || { echo "Missing $GLOBAL_HARNESS_DIR/visual-check.mjs" >&2; exit 1; }
  [[ -f "$GLOBAL_HARNESS_DIR/CLAUDE_CODE_PROMPT.md" ]] || { echo "Missing $GLOBAL_HARNESS_DIR/CLAUDE_CODE_PROMPT.md" >&2; exit 1; }
  [[ -f "$PWD/package.json" ]] || { echo "Missing package.json in $PWD; run from a JS/Next project root" >&2; exit 1; }

  mkdir -p "$PWD/scripts"
  for spec in \
    "$GLOBAL_HARNESS_DIR/visual-check.mjs:$PWD/scripts/visual-check.mjs" \
    "$GLOBAL_HARNESS_DIR/CLAUDE_CODE_PROMPT.md:$PWD/CLAUDE_CODE_PROMPT.md"; do
    src="${spec%%:*}"
    dst="${spec#*:}"
    if [[ -e "$dst" && $force -ne 1 ]]; then
      echo "skip: $dst exists (use --force to overwrite)"
      continue
    fi
    cp "$src" "$dst"
    echo "copied: $dst"
  done

  python3 - "$PWD/package.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
data.setdefault("scripts", {})["test:visual"] = "node scripts/visual-check.mjs"
dev = data.setdefault("devDependencies", {})
dev.setdefault("@axe-core/playwright", "^4.11.3")
dev.setdefault("@playwright/test", "^1.59.1")
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
PY
  echo "updated: $PWD/package.json"
  echo "Next steps: pnpm install && pnpm lint && pnpm build && pnpm test:visual"
}


init_mobile_harness() {
  local force=0
  local target="$PWD/packages/mobile-ui/src/design-harness.tsx"
  while (($#)); do
    case "$1" in
      --force) force=1 ;;
      --path)
        shift
        [[ $# -gt 0 ]] || { echo "--path requires a file path" >&2; exit 2; }
        case "$1" in /*) target="$1" ;; *) target="$PWD/$1" ;; esac
        ;;
      --path=*)
        raw_path="${1#--path=}"
        case "$raw_path" in /*) target="$raw_path" ;; *) target="$PWD/$raw_path" ;; esac
        ;;
      *) echo "Unknown init-mobile-harness argument: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
  done

  local src="$GLOBAL_HARNESS_DIR/mobile-expo-iphone17-pro-max-harness.tsx"
  [[ -f "$src" ]] || { echo "Missing $src" >&2; exit 1; }

  if [[ -e "$target" && $force -ne 1 ]]; then
    echo "skip: $target exists (use --force to overwrite)"
  else
    mkdir -p "$(dirname "$target")"
    cp "$src" "$target"
    echo "copied: $target"
  fi

  cat <<EOF_NEXT
Next steps:
  - Export Iphone17ProMaxDesignHarness from the target module or barrel file.
  - Wrap the comparison/prototype Expo Router Stack in Iphone17ProMaxDesignHarness.
  - Keep production native apps on the real SafeAreaProvider path.
  - Verify with app typecheck/lint and browser screenshots.
EOF_NEXT
}

add_inspiration() {
  [[ $# -eq 1 ]] || { echo "getdesign add requires a slug, e.g. cursor, linear.app, vercel" >&2; exit 2; }
  local slug="$1"
  command -v npx >/dev/null 2>&1 || { echo "npx is required for getdesign catalog installs" >&2; exit 1; }
  npx getdesign@latest add "$slug"
  echo "Installed getdesign.md inspiration: $slug"
  echo "Now ask your agent to use ./DESIGN.md for UI work."
}

doctor_design() {
  local errors=0
  for f in \
    "$HOME/DESIGN.md:$GLOBAL_DESIGN" \
    "$HOME/getdesign.md:$GLOBAL_GETDESIGN" \
    "$HOME/.claude/DESIGN.md:$GLOBAL_DESIGN" \
    "$HOME/.claude/getdesign.md:$GLOBAL_GETDESIGN" \
    "$HOME/.codex/DESIGN.md:$GLOBAL_DESIGN" \
    "$HOME/.codex/getdesign.md:$GLOBAL_GETDESIGN"; do
    link="${f%%:*}"
    target="${f#*:}"
    if [[ -L "$link" && "$(real_path "$link")" == "$(real_path "$target")" ]]; then
      echo "✓ $link -> $target"
    else
      echo "✗ $link does not resolve to $target"
      errors=$((errors + 1))
    fi
  done
  for f in \
    "$GLOBAL_DESIGN" \
    "$GLOBAL_GETDESIGN" \
    "$GLOBAL_HARNESS_DIR/visual-check.mjs" \
    "$GLOBAL_HARNESS_DIR/CLAUDE_CODE_PROMPT.md" \
    "$GLOBAL_HARNESS_DIR/mobile-expo-iphone17-pro-max-harness.tsx" \
    "$GLOBAL_HARNESS_DIR/README.md"; do
    if [[ -f "$f" ]]; then
      echo "✓ exists: $f"
    else
      echo "✗ missing: $f"
      errors=$((errors + 1))
    fi
  done
  exit "$errors"
}

cmd="${1:-show}"
case "$cmd" in
  show) shift || true; show_context "$@" ;;
  init|copy) shift; init_project "$@" ;;
  init-harness|harness) shift; init_harness "$@" ;;
  init-mobile-harness|mobile-harness) shift; init_mobile_harness "$@" ;;
  add) shift; add_inspiration "$@" ;;
  doctor) shift || true; doctor_design "$@" ;;
  -h|--help|help) usage ;;
  *) echo "Unknown command: $cmd" >&2; usage >&2; exit 2 ;;
esac
