#!/usr/bin/env bash
# verify-codex-skill-sync.sh
# Verifies the intended invariant:
#   every Claude Code skill name is available in Codex.
#
# This intentionally does NOT require Claude == Codex. Codex has additional
# Codex/OMX/system skills that should remain Codex-only.

set -euo pipefail

CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
CODEX_SKILLS_DIR="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
LEGACY_SKILLS_DIR="${LEGACY_SKILLS_DIR:-$HOME/.agents/skills}"
run_doctor=1

usage() {
  cat <<'EOF'
Usage: verify-codex-skill-sync.sh [--skip-doctor]

Checks:
  - Claude skill names are all present in Codex
  - Codex skill root has no broken symlinks
  - top-level Codex skill symlinks are relative, not machine-absolute
  - ~/.agents/skills resolves to ~/.codex/skills
  - omx doctor reports 0 warnings / 0 failed unless --skip-doctor is used
EOF
}

while (($#)); do
  case "$1" in
    --skip-doctor) run_doctor=0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

real_path() {
  python3 - "$1" <<'PY'
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

errors=0

if [[ ! -d "$CLAUDE_SKILLS_DIR" ]]; then
  echo "FAIL: Claude skills dir not found: $CLAUDE_SKILLS_DIR"
  exit 1
fi

if [[ ! -d "$CODEX_SKILLS_DIR" ]]; then
  echo "FAIL: Codex skills dir not found: $CODEX_SKILLS_DIR"
  exit 1
fi

find -L "$CLAUDE_SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort > "$tmp/claude.txt"
find -L "$CODEX_SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort > "$tmp/codex.txt"

claude_count="$(wc -l < "$tmp/claude.txt" | tr -d ' ')"
codex_count="$(wc -l < "$tmp/codex.txt" | tr -d ' ')"
shared_count="$(comm -12 "$tmp/claude.txt" "$tmp/codex.txt" | wc -l | tr -d ' ')"

missing_file="$tmp/missing.txt"
comm -23 "$tmp/claude.txt" "$tmp/codex.txt" > "$missing_file"

echo "Claude skills: $claude_count"
echo "Codex skills:  $codex_count"
echo "Shared names:  $shared_count"

if [[ -s "$missing_file" ]]; then
  echo ""
  echo "FAIL: Claude skills missing in Codex:"
  sed 's/^/  - /' "$missing_file"
  errors=$((errors + 1))
else
  echo "OK: every Claude skill name is available in Codex"
fi

broken_file="$tmp/broken.txt"
find "$CODEX_SKILLS_DIR" -type l -print | while IFS= read -r link_path; do
  [[ -e "$link_path" ]] || printf '%s\n' "$link_path"
done | sort > "$broken_file"
if [[ -s "$broken_file" ]]; then
  echo ""
  echo "FAIL: broken symlinks under Codex skills:"
  sed 's/^/  - /' "$broken_file"
  errors=$((errors + 1))
else
  echo "OK: no broken symlinks under Codex skills"
fi

absolute_file="$tmp/absolute.txt"
find "$CODEX_SKILLS_DIR" -mindepth 1 -maxdepth 1 -type l -exec sh -c '
  for p do
    target="$(readlink "$p")"
    case "$target" in
      /*) printf "%s -> %s\n" "$p" "$target" ;;
    esac
  done
' sh {} + | sort > "$absolute_file"
if [[ -s "$absolute_file" ]]; then
  echo ""
  echo "FAIL: top-level Codex skill symlinks use absolute paths:"
  sed 's/^/  - /' "$absolute_file"
  errors=$((errors + 1))
else
  echo "OK: top-level Codex skill symlinks are relative"
fi

if [[ -e "$LEGACY_SKILLS_DIR" || -L "$LEGACY_SKILLS_DIR" ]]; then
  if [[ "$(real_path "$LEGACY_SKILLS_DIR")" == "$(real_path "$CODEX_SKILLS_DIR")" ]]; then
    echo "OK: legacy ~/.agents/skills resolves to Codex canonical skills"
  else
    echo ""
    echo "FAIL: legacy ~/.agents/skills does not resolve to Codex canonical skills"
    echo "  legacy: $LEGACY_SKILLS_DIR -> $(real_path "$LEGACY_SKILLS_DIR")"
    echo "  codex:  $CODEX_SKILLS_DIR -> $(real_path "$CODEX_SKILLS_DIR")"
    errors=$((errors + 1))
  fi
else
  echo ""
  echo "FAIL: legacy ~/.agents/skills is absent; expected symlink to Codex canonical skills"
  errors=$((errors + 1))
fi

if (( run_doctor == 1 )); then
  doctor_out="$tmp/omx-doctor.txt"
  if (cd "$HOME" && omx doctor) > "$doctor_out" 2>&1 && grep -q '0 warnings, 0 failed' "$doctor_out"; then
    echo "OK: omx doctor reports 0 warnings / 0 failed"
  else
    echo ""
    echo "FAIL: omx doctor did not report 0 warnings / 0 failed"
    sed -n '1,160p' "$doctor_out"
    errors=$((errors + 1))
  fi
fi

if (( errors > 0 )); then
  echo ""
  echo "Skill sync verification FAILED ($errors issue group(s))"
  exit 1
fi

echo ""
echo "Skill sync verification PASSED"
