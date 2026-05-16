#!/usr/bin/env bash
# Create or reuse a per-task docs/work-log folder with context/plan/checklist.
# Explicit workflow-start harness; intentionally not wired to SessionStart.
set -euo pipefail

ROOT=""
SLUG=""
TITLE=""
JSON=0

usage() {
  cat <<'EOF'
Usage: ensure-work-log-task.sh [--root DIR] [--slug SLUG] [--title TITLE] [--json]

Folder name is ALWAYS: docs/work-log/YYYY-MM-DD_<feature-slug>/
(date prefix is forced even when --slug is given; separator is "_")

Creates:
  docs/work-log/YYYY-MM-DD_<feature>/context.md
  docs/work-log/YYYY-MM-DD_<feature>/plan.md
  docs/work-log/YYYY-MM-DD_<feature>/checklist.md

The script is idempotent and does not overwrite existing files.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      ROOT="${2:-}"; shift 2 ;;
    --slug)
      SLUG="${2:-}"; shift 2 ;;
    --title)
      TITLE="${2:-}"; shift 2 ;;
    --json)
      JSON=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      if [ -z "$TITLE" ]; then
        TITLE="$1"
      else
        TITLE="$TITLE $1"
      fi
      shift ;;
  esac
done

if [ -z "$ROOT" ]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi

case "$ROOT" in
  /|/System|/System/*|/Library|/Library/*|/bin|/bin/*|/sbin|/sbin/*|/usr|/usr/bin|/usr/sbin|/private|/private/tmp|/tmp)
    echo "Refusing unsafe project root: $ROOT" >&2
    exit 2
    ;;
esac

mkdir -p "$ROOT"
ROOT="$(cd "$ROOT" && pwd)"

if [ -z "$TITLE" ]; then
  TITLE="Task work log"
fi

# Keep unicode letters (e.g. Korean) intact; only lowercase ASCII,
# collapse whitespace to "-", and strip path-unsafe characters.
slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -s ' \t\r\n' '-' \
    | sed -E 's#[/\\:*?"<>|[:cntrl:]]+##g; s/-{2,}/-/g; s/^[-_.]+//; s/[-_.]+$//' \
    | cut -c 1-80
}

# Folder convention is always: YYYY-MM-DD_<feature-slug>
# Applies whether --slug or --title (or bare title) was provided.
DATE="$(date +%Y-%m-%d)"
if [ -n "$SLUG" ]; then
  feature="$(slugify "$SLUG")"
else
  feature="$(slugify "$TITLE")"
fi
# Strip any leading date the caller may have already embedded to avoid
# producing YYYY-MM-DD_YYYY-MM-DD_feature.
feature="$(printf '%s' "$feature" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}[_-]+//')"
[ -n "$feature" ] || feature="task"
SLUG="${DATE}_${feature}"

SYNC_HOME="${AGENT_HARNESS_BASELINE_HOME:-$HOME/.config/agent-harness-baseline}"
if [ -x "$SYNC_HOME/bin/ensure-project-layout.sh" ]; then
  printf '{"cwd":"%s"}\n' "$ROOT" | "$SYNC_HOME/bin/ensure-project-layout.sh" >/dev/null 2>&1 || true
fi

WORKLOG_DIR="$ROOT/docs/work-log/$SLUG"
mkdir -p "$WORKLOG_DIR"

create_if_missing() {
  local path="$1"
  local content="$2"
  if [ ! -e "$path" ]; then
    printf '%s\n' "$content" > "$path"
  fi
}

today="$(date +%Y-%m-%d)"

create_if_missing "$WORKLOG_DIR/context.md" "# Context

- Task: $TITLE
- Created: $today
- Request:
- Evidence:
- Constraints:
- Decisions:
- Related files:
"

create_if_missing "$WORKLOG_DIR/plan.md" "# Plan

- Target outcome:
- Approach:
- Expected change areas:
- Validation strategy:
- Rollback or risk notes:

## Steps

1. [ ] Capture context and acceptance criteria.
2. [ ] Implement the smallest safe change.
3. [ ] Run targeted validation.
4. [ ] Update checklist and remaining risks.
"

create_if_missing "$WORKLOG_DIR/checklist.md" "# Checklist

- [ ] Context captured in context.md
- [ ] Plan captured in plan.md
- [ ] Acceptance criteria are explicit
- [ ] Implementation completed or intentionally deferred
- [ ] Tests/lint/typecheck run as applicable
- [ ] Remaining risks documented
- [ ] Final outcome summarized
"

if [ "$JSON" -eq 1 ]; then
  python3 - "$ROOT" "$WORKLOG_DIR" "$SLUG" "$TITLE" <<'PY'
import json
import sys

root, path, slug, title = sys.argv[1:]
print(json.dumps({
    "root": root,
    "work_log_dir": path,
    "slug": slug,
    "title": title,
    "files": {
        "context": f"{path}/context.md",
        "plan": f"{path}/plan.md",
        "checklist": f"{path}/checklist.md",
    },
}, ensure_ascii=False))
PY
else
  printf '%s\n' "$WORKLOG_DIR"
fi
