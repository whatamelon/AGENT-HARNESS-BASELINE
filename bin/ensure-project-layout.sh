#!/usr/bin/env bash
# Ensure the user's standard development-project layout exists in the current session directory.
# Explicit scaffold helper only. Safe, idempotent, and non-destructive.
set -u

stdin_payload="$(cat 2>/dev/null || true)"
resolve_cwd() {
  if [ -n "$stdin_payload" ] && command -v python3 >/dev/null 2>&1; then
    PROJECT_LAYOUT_STDIN="$stdin_payload" python3 - <<'PY' 2>/dev/null
import json, os
try:
    data = json.loads(os.environ.get('PROJECT_LAYOUT_STDIN', ''))
except Exception:
    data = {}
for key in ('cwd', 'current_working_directory', 'workspace', 'workspace_root', 'project_dir'):
    value = data.get(key) if isinstance(data, dict) else None
    if isinstance(value, str) and value.strip():
        print(value.strip())
        raise SystemExit(0)
print('')
PY
    return
  fi
  printf '%s\n' "${PWD:-}"
}

project_dir="$(resolve_cwd)"
[ -n "$project_dir" ] || project_dir="${PWD:-}"
[ -n "$project_dir" ] || exit 0
case "$project_dir" in
  /|/System|/System/*|/Library|/Library/*|/bin|/bin/*|/sbin|/sbin/*|/usr|/usr/bin|/usr/sbin|/private|/private/tmp|/tmp)
    exit 0
    ;;
esac

mkdir -p "$project_dir/docs/work-log/_template" "$project_dir/apps" "$project_dir/packages" "$project_dir/.project"

# Keep empty directories visible to git without overwriting user files.
for dir in "$project_dir/apps" "$project_dir/packages" "$project_dir/.project"; do
  [ -e "$dir/.gitkeep" ] || : > "$dir/.gitkeep"
done

create_if_missing() {
  path="$1"
  content="$2"
  if [ ! -e "$path" ]; then
    printf '%s\n' "$content" > "$path"
  fi
}

create_if_missing "$project_dir/docs/work-log/_template/context.md" '# Context

- Why this work exists:
- Product/technical background:
- Repo/layout evidence:
- Decisions and constraints:
- Related requests, issues, or evidence:
'
create_if_missing "$project_dir/docs/work-log/_template/plan.md" '# Plan

- Target outcome:
- Approach:
- Files/areas expected to change:
- App/package boundaries:
- Validation strategy:
- Rollback or risk notes:
'
create_if_missing "$project_dir/docs/work-log/_template/checklist.md" '# Checklist

- [ ] Context captured
- [ ] Implementation plan reviewed
- [ ] Acceptance criteria defined
- [ ] App/package boundaries match requirements
- [ ] Code implemented
- [ ] Tests/lint/typecheck run as applicable
- [ ] Remaining risks documented
'

exit 0
