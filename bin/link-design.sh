#!/usr/bin/env bash
# Link shared DESIGN.md/getdesign.md entrypoints into home, Claude Code, and Codex.
set -euo pipefail

SSOT="${AGENT_HARNESS_BASELINE_HOME:-$HOME/.config/agent-harness-baseline}"
DESIGN_DIR="$SSOT/design"

[[ -f "$DESIGN_DIR/DESIGN.md" ]] || { echo "Missing $DESIGN_DIR/DESIGN.md" >&2; exit 1; }
[[ -f "$DESIGN_DIR/getdesign.md" ]] || { echo "Missing $DESIGN_DIR/getdesign.md" >&2; exit 1; }

link_one() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    mv "$dst" "$dst.bak.$(date +%s)"
  fi
  ln -sfn "$src" "$dst"
}

for base in "$HOME" "$HOME/.claude" "$HOME/.codex"; do
  link_one "$DESIGN_DIR/DESIGN.md" "$base/DESIGN.md"
  link_one "$DESIGN_DIR/getdesign.md" "$base/getdesign.md"
done

echo "✓ linked DESIGN.md/getdesign.md for home, Claude Code, and Codex"
