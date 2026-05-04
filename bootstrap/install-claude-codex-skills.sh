#!/usr/bin/env bash
# install-claude-codex-skills.sh
# Expose Codex-visible skills back into Claude Code so both tools present the
# same visible skill-name set. Codex/OMX-native skills remain implemented at
# their Codex source path; Claude gets relative symlinks.

set -euo pipefail

CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
CODEX_SKILLS_DIR="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"

[[ -d "$CLAUDE_SKILLS_DIR" ]] || { echo "ℹ️  Claude skills dir 없음: $CLAUDE_SKILLS_DIR — skip"; exit 0; }
[[ -d "$CODEX_SKILLS_DIR" ]] || { echo "ℹ️  Codex skills dir 없음: $CODEX_SKILLS_DIR — skip"; exit 0; }

real_path() {
  python3 - "$1" <<'PY'
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
}

rel_link_target() {
  python3 - "$1" "$2" <<'PY'
import os, sys
src, dst_dir = sys.argv[1], sys.argv[2]
print(os.path.relpath(os.path.realpath(src), os.path.realpath(dst_dir)))
PY
}

same_link_target() {
  local link_path="$1" src_path="$2"
  [[ -L "$link_path" ]] || return 1
  local current
  current="$(readlink "$link_path")"
  case "$current" in
    /*) [[ "$(real_path "$current")" == "$(real_path "$src_path")" ]] ;;
    *) [[ "$(python3 -c 'import os,sys; print(os.path.realpath(os.path.join(os.path.dirname(sys.argv[1]), sys.argv[2])))' "$link_path" "$current")" == "$(real_path "$src_path")" ]] ;;
  esac
}

is_under() {
  local child="$1" parent="$2"
  python3 - "$child" "$parent" <<'PY'
import os, sys
child, parent = map(os.path.realpath, sys.argv[1:3])
try:
    common = os.path.commonpath([child, parent])
except ValueError:
    sys.exit(1)
sys.exit(0 if common == parent else 1)
PY
}

CLAUDE_REAL="$(real_path "$CLAUDE_SKILLS_DIR")"

echo "▶ Codex 스킬을 Claude Code surface로 동기화"

removed_broken=0
added=0
skipped=0
relinked=0
loops=0
conflicts=0
total=0

while IFS= read -r link_path; do
  if [[ ! -e "$link_path" ]]; then
    echo "  - removed broken Claude skill link: $(basename "$link_path")"
    rm -f "$link_path"
    ((removed_broken+=1))
  fi
done < <(find -L "$CLAUDE_SKILLS_DIR" -mindepth 1 -maxdepth 1 -type l | sort)

while IFS= read -r src; do
  name="$(basename "$src")"
  dst="$CLAUDE_SKILLS_DIR/$name"

  [[ -f "$src/SKILL.md" ]] || continue
  ((total+=1))

  src_real="$(real_path "$src")"
  if is_under "$src_real" "$CLAUDE_REAL"; then
    ((loops+=1))
    continue
  fi

  link_target="$(rel_link_target "$src" "$(dirname "$dst")")"

  if [[ -L "$dst" ]]; then
    if same_link_target "$dst" "$src"; then
      ((skipped+=1))
      continue
    fi
    rm "$dst"
    ln -s "$link_target" "$dst"
    echo "  ↻ relinked: $name"
    ((relinked+=1))
  elif [[ -e "$dst" ]]; then
    if [[ "$(real_path "$dst")" == "$src_real" ]]; then
      ((skipped+=1))
      continue
    fi
    echo "  ⚠️  conflict: $name — Claude에 같은 이름의 실제 파일/디렉터리가 이미 존재"
    ((conflicts+=1))
  else
    ln -s "$link_target" "$dst"
    echo "  + added: $name"
    ((added+=1))
  fi
done < <(find -L "$CODEX_SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

echo ""
echo "  total: $total, added: $added, relinked: $relinked, skipped: $skipped, loops: $loops, removed_broken: $removed_broken, conflicts: $conflicts"

if (( conflicts > 0 )); then
  exit 1
fi
