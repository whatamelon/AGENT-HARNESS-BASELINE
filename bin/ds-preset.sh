#!/usr/bin/env bash
# ds-preset — activate / inspect ANDS design-token presets for the Flutter harness.
#
# The ds package has ONE active SSOT: packages/ds/tokens/tokens.json.
# Presets live in packages/ds/tokens/presets/*.json (same schema, drop-in).
# Activating a preset copies it over tokens.json, regenerates the Dart token
# files, and verifies the drift gate — atomically (restores on any failure).
#
# Usage:
#   ds-preset                 # = list
#   ds-preset list            # show available presets, mark active
#   ds-preset status          # show currently active preset
#   ds-preset <name>          # activate presets/<name>.json (e.g. ands | uniqlo)
#   ds-preset <name> --test   # also run `flutter test` after gen (slower)
#
# Scope caveat: tokens.json is shared by every app depending on
# `path: ../../packages/ds`. Activating a preset is a WORKSPACE-LEVEL choice.
# Per-app Primary color is the brick `brand_seed` var (buildTheme), not this.

set -euo pipefail

# Resolve harness root from this script's location (symlink-safe).
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
BIN_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
ROOT="$(cd "$BIN_DIR/.." && pwd)"
DS="$ROOT/flutter/packages/ds"
TOKENS="$DS/tokens/tokens.json"
PRESETS="$DS/tokens/presets"
GEN="$DS/lib/src/gen"

die() { echo "ds-preset: $*" >&2; exit 1; }
[ -d "$DS" ] || die "ds package not found at $DS"

# meta.preset of a tokens json (prints 'base' if absent / unreadable).
preset_of() {
  python3 - "$1" <<'PY' 2>/dev/null || echo "base"
import json, sys
d = json.load(open(sys.argv[1]))
print(d.get("meta", {}).get("preset", "base"))
PY
}
ref_of() {
  python3 - "$1" <<'PY' 2>/dev/null || echo ""
import json, sys
d = json.load(open(sys.argv[1]))
print(d.get("meta", {}).get("reference", ""))
PY
}

cmd_status() {
  local active; active="$(preset_of "$TOKENS")"
  echo "active preset: $active"
  echo "  reference: $(ref_of "$TOKENS")"
}

cmd_list() {
  local active; active="$(preset_of "$TOKENS")"
  echo "presets ($PRESETS):"
  shopt -s nullglob
  for f in "$PRESETS"/*.json; do
    local name; name="$(basename "$f" .json)"
    local p; p="$(preset_of "$f")"
    local mark="  "; [ "$p" = "$active" ] && mark="* "
    printf "%s%-10s %s\n" "$mark" "$name" "$(ref_of "$f")"
  done
  echo "(* = active)  active=$active"
}

cmd_activate() {
  local name="$1"; local run_test="${2:-}"
  local src="$PRESETS/$name.json"
  [ -f "$src" ] || die "preset '$name' not found ($src). Try: ds-preset list"
  python3 -c "import json;json.load(open('$src'))" || die "preset '$name' is not valid JSON"

  local dart; dart="$(command -v fvm >/dev/null 2>&1 && echo 'fvm dart' || echo 'dart')"
  local to;  to="$(command -v gtimeout || true)"

  # Backup current state for atomic restore.
  local bk; bk="$(mktemp -d)"
  cp "$TOKENS" "$bk/tokens.json"
  [ -d "$GEN" ] && cp -r "$GEN" "$bk/gen"
  restore() { cp "$bk/tokens.json" "$TOKENS"; [ -d "$bk/gen" ] && { rm -rf "$GEN"; cp -r "$bk/gen" "$GEN"; }; rm -rf "$bk"; }

  echo "activating preset: $name"
  cp "$src" "$TOKENS"

  echo "→ regenerating Dart tokens…"
  if ! ( cd "$DS" && ${to:+$to 180} $dart run tool/gen_tokens.dart ); then
    restore; die "token generation failed — restored previous state"
  fi
  echo "→ drift check…"
  if ! ( cd "$DS" && $dart run tool/gen_tokens.dart --check ); then
    restore; die "drift check failed — restored previous state"
  fi
  if [ "$run_test" = "--test" ]; then
    echo "→ flutter test…"
    if ! ( cd "$DS" && ${to:+$to 600} fvm flutter test ); then
      restore; die "flutter test failed — restored previous state"
    fi
  fi
  rm -rf "$bk"
  echo "✓ active preset: $(preset_of "$TOKENS")  ($(ref_of "$TOKENS"))"
  echo "  generated: $GEN/*.dart  (commit these)"
}

case "${1:-list}" in
  list|"")   cmd_list ;;
  status)    cmd_status ;;
  -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//' ;;
  *)         cmd_activate "$1" "${2:-}" ;;
esac
