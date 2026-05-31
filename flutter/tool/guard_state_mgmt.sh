#!/usr/bin/env bash
#
# guard_state_mgmt.sh — state-management drift gate.
#
# Riverpod 3.x is the LOCKED state foundation of this harness
# (see docs/STATE_MANAGEMENT.md). This guard fails the build if shipped
# library code reintroduces legacy Riverpod APIs or a competing
# state/DI library. The real risk is not a deliberate library switch — it
# is AI-agent pattern drift (an LLM reaching for StateNotifier/GetX from
# its training data). This script makes that drift a hard CI failure.
#
# Usage:
#   bash tool/guard_state_mgmt.sh        # zero violations -> exit 0, else exit 1
#
# Recommended melos registration (root pubspec.yaml `melos.scripts`, owned
# by the cache lane — NOT edited here):
#   guard:state:
#     description: Fail if legacy Riverpod / 2nd state-DI library leaks into lib/.
#     run: bash tool/guard_state_mgmt.sh
#
# Scope: only shipped library code under packages/*/lib and apps/*/lib.
# Excluded (false-positive avoidance):
#   - bricks/**           Mason templates ({{app_name}} mustache), not workspace code
#   - **/*.g.dart, **/*.freezed.dart, packages/ds/lib/src/gen/**  generated output
#   - test/ dirs          live outside lib/, so already out of scope
#   - comment lines (//, ///, * ) — doc comments legitimately name the banned
#     APIs while explaining the ban (e.g. auth_state.dart), so they are stripped
#     before matching to avoid flagging the documentation itself.
#
# Matching uses identifier word boundaries so legitimate Riverpod 3 symbols
# that merely *contain* a banned substring are NOT flagged. The canonical
# trap: `authStateProvider` contains the substring "StateProvider"; an
# unanchored grep flags 37 false positives, the anchored form flags 0.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Banned identifiers (anchored on identifier boundaries below).
# Legacy Riverpod state APIs superseded by Notifier/AsyncNotifier in 3.x:
BANNED_IDENTS=(
  'StateProvider'
  'StateProviderFamily'
  'StateNotifier'
  'StateNotifierProvider'
  'ChangeNotifierProvider'
)

# Banned package imports: competing state / DI stacks.
BANNED_IMPORTS=(
  'package:get/'
  'package:getx'
  'package:provider/'
)

# Build the list of in-scope library files (bash 3.2-portable: no mapfile).
# A temp file keeps the list independent of the awk subshell below.
SCAN_LIST="$(mktemp)"
trap 'rm -f "$SCAN_LIST"' EXIT
find packages apps -type f -name '*.dart' \
  -path '*/lib/*' \
  -not -name '*.g.dart' \
  -not -name '*.freezed.dart' \
  -not -path '*/lib/src/gen/*' \
  2>/dev/null | sort > "$SCAN_LIST"

scan_count="$(wc -l < "$SCAN_LIST" | tr -d ' ')"
if [[ "$scan_count" -eq 0 ]]; then
  echo "guard:state OK — no library Dart files in scope."
  exit 0
fi

# Identifier boundary: a banned identifier must be preceded and followed by a
# non-identifier char (or line edge). Implemented per-line in awk after
# stripping comments.
ID_PATTERN="$(IFS='|'; echo "${BANNED_IDENTS[*]}")"
IMPORT_PATTERN="$(IFS='|'; echo "${BANNED_IMPORTS[*]}")"

violations=0

while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  # awk: strip line comments, then test each line for a boundary-anchored
  # banned identifier or a banned import. Prints "<lineno>:<reason>:<text>".
  result="$(
    awk -v idpat="$ID_PATTERN" -v imppat="$IMPORT_PATTERN" '
      {
        raw = $0
        line = $0
        # Strip from the first // (line comment). Crude but sufficient: any
        # banned token living only inside a doc/line comment is intentionally
        # ignored. Block comments / strings are a known minor blind spot,
        # acceptable for a leak gate (real code use is what we catch).
        ci = index(line, "//")
        if (ci > 0) line = substr(line, 1, ci - 1)
        # Skip pure doc-comment / block-comment continuation lines.
        stripped = line
        sub(/^[ \t]+/, "", stripped)
        if (stripped ~ /^\*/ || stripped == "") next

        # Banned imports (substring match inside an import/export directive).
        if (line ~ /^[ \t]*(import|export)[ \t]/ && line ~ ("(" imppat ")")) {
          printf "%d:banned-import:%s\n", NR, raw
          next
        }

        # Boundary-anchored banned identifier.
        n = split(idpat, ids, "|")
        for (i = 1; i <= n; i++) {
          tok = ids[i]
          # Find tok with non-identifier neighbours.
          rest = line
          while (match(rest, tok)) {
            start = RSTART
            before = (start == 1) ? "" : substr(rest, start - 1, 1)
            afterpos = start + length(tok)
            after = (afterpos > length(rest)) ? "" : substr(rest, afterpos, 1)
            ok_before = (before == "" || before !~ /[A-Za-z0-9_]/)
            ok_after  = (after  == "" || after  !~ /[A-Za-z0-9_]/)
            if (ok_before && ok_after) {
              printf "%d:banned-api(%s):%s\n", NR, tok, raw
              break
            }
            rest = substr(rest, start + length(tok))
          }
        }
      }
    ' "$file"
  )"

  if [[ -n "$result" ]]; then
    while IFS= read -r hit; do
      lineno="${hit%%:*}"
      rest="${hit#*:}"
      reason="${rest%%:*}"
      text="${rest#*:}"
      echo "VIOLATION ${file}:${lineno} [${reason}] ${text#"${text%%[![:space:]]*}"}"
      violations=$((violations + 1))
    done <<< "$result"
  fi
done < "$SCAN_LIST"

if [[ $violations -gt 0 ]]; then
  echo ""
  echo "guard:state FAILED — ${violations} legacy state-management usage(s)."
  echo "Riverpod 3.x is locked. Use Notifier / AsyncNotifier (see docs/STATE_MANAGEMENT.md)."
  exit 1
fi

echo "guard:state OK — scanned ${scan_count} library file(s), 0 violations."
exit 0
