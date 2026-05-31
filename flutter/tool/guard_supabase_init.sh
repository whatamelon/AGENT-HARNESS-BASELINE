#!/usr/bin/env bash
#
# guard_supabase_init.sh — single-init-site gate (§5.1 P0 security).
#
# `Supabase.initialize` MUST be called from exactly ONE place:
#   packages/app_kit/lib/src/auth/auth_wiring.dart  (initSupabaseSecure)
# which wires H-5 secure session + PKCE storage. The default supabase_flutter
# init persists the refresh token to PLAINTEXT `shared_preferences`; if any
# other file calls `Supabase.initialize` it bypasses the secure storage and
# silently reintroduces the P0 plaintext-token bug. This guard makes that a
# hard CI failure so the insecure path can never come back unnoticed.
#
# Usage:
#   bash tool/guard_supabase_init.sh    # zero stray inits -> exit 0, else exit 1
#
# Recommended melos registration (root pubspec.yaml `melos.scripts`):
#   guard:supabase-init:
#     description: Fail if Supabase.initialize is called outside auth_wiring.dart.
#     run: bash tool/guard_supabase_init.sh
#
# Scope: shipped library + app code under packages/*/lib and apps/*/lib, plus
# the Mason brick templates under bricks/** (so a generated app can't smuggle in
# an insecure init). Excludes generated output and comment-only mentions (the
# allowed site and docs name the API while explaining the rule).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# The one file allowed to call Supabase.initialize.
ALLOWED_FILE="packages/app_kit/lib/src/auth/auth_wiring.dart"

# Match `Supabase.initialize` (optionally namespaced, e.g. `sb.Supabase`).
PATTERN='(^|[^A-Za-z0-9_.])([A-Za-z_][A-Za-z0-9_]*\.)?Supabase\.initialize'

SCAN_LIST="$(mktemp)"
trap 'rm -f "$SCAN_LIST"' EXIT
find packages apps bricks -type f -name '*.dart' \
  -path '*/lib/*' \
  -not -name '*.g.dart' \
  -not -name '*.freezed.dart' \
  -not -path '*/lib/src/gen/*' \
  2>/dev/null | sort > "$SCAN_LIST"

scan_count="$(wc -l < "$SCAN_LIST" | tr -d ' ')"
if [[ "$scan_count" -eq 0 ]]; then
  echo "guard:supabase-init OK — no library Dart files in scope."
  exit 0
fi

violations=0

while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  [[ "$file" == "$ALLOWED_FILE" ]] && continue

  file_violation=0

  # ── Pass 1 (multiline, portable): Perl slurps the whole file and strips
  #   // line-comments and * doc-comment-continuation lines, then matches
  #   `Supabase\s*\.\s*initialize` across newlines.  This catches the
  #   dart-formatted split `Supabase\n    .initialize(` that the line-by-line
  #   awk pass below cannot see.  Perl is available on macOS and all CI
  #   images; no dependency on GNU grep -P.
  if perl -0777 -ne '
      s{//[^\n]*}{}g;          # strip // line comments
      s{^\s*\*[^\n]*}{}mg;     # strip * doc-comment continuation lines
      exit 0 if /(?<![A-Za-z0-9_.])[A-Za-z_][A-Za-z0-9_]*\s*\.\s*initialize\s*\(/ &&
                /Supabase\s*\.\s*initialize/;
      exit 1;
    ' "$file" 2>/dev/null; then
    echo "VIOLATION ${file}: multiline Supabase.initialize detected (Perl pass)"
    violations=$((violations + 1))
    file_violation=1
  fi

  # ── Pass 2 (line-by-line): awk strips line comments and block-comment
  #   continuation lines, then matches on each individual line.  Catches the
  #   single-line form `Supabase.initialize(` and provides precise line numbers.
  #   Skipped if Pass 1 already flagged this file (avoids double-counting).
  if [[ $file_violation -eq 0 ]]; then
    result="$(
      awk -v pat="$PATTERN" '
        {
          raw = $0
          line = $0
          ci = index(line, "//")
          if (ci > 0) line = substr(line, 1, ci - 1)
          stripped = line
          sub(/^[ \t]+/, "", stripped)
          if (stripped ~ /^\*/ || stripped == "") next
          if (line ~ pat) {
            printf "%d:%s\n", NR, raw
          }
        }
      ' "$file"
    )"

    if [[ -n "$result" ]]; then
      while IFS= read -r hit; do
        lineno="${hit%%:*}"
        text="${hit#*:}"
        echo "VIOLATION ${file}:${lineno} ${text#"${text%%[![:space:]]*}"}"
        violations=$((violations + 1))
      done <<< "$result"
    fi
  fi
done < "$SCAN_LIST"

if [[ $violations -gt 0 ]]; then
  echo ""
  echo "guard:supabase-init FAILED — ${violations} stray Supabase.initialize call(s)."
  echo "Only ${ALLOWED_FILE} (initSupabaseSecure) may call Supabase.initialize."
  echo "It wires H-5 secure session + PKCE storage; any other init persists the"
  echo "refresh token in PLAINTEXT shared_preferences (§5.1 P0)."
  exit 1
fi

echo "guard:supabase-init OK — scanned ${scan_count} file(s), 0 stray init(s)."
exit 0
