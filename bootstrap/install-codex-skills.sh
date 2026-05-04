#!/usr/bin/env bash
# install-codex-skills.sh
# Claude Code에서 보이는 모든 스킬을 Codex canonical ~/.codex/skills/에서도
# 같은 이름으로 사용할 수 있게 한다.
#
# - 멱등(idempotent): 이미 올바른 심링크면 skip, 깨진 링크는 재생성
# - Claude skills의 실제 디렉터리와 유효한 symlink 디렉터리를 모두 처리
# - 이미 Codex canonical/legacy root로 되돌아가는 순환 링크는 skip
# - 회사 맥북 부트스트랩 + 평소 sync 양쪽에서 호출 가능

set -euo pipefail

CC_SKILLS_DIR="$HOME/.config/claude-sync/claude/skills"
CODEX_SKILLS_DIR="$HOME/.codex/skills"

if [[ ! -d "$CODEX_SKILLS_DIR" ]]; then
  echo "ℹ️  ~/.codex/skills 없음 — Codex 미설치이거나 초기화 전. skip"
  exit 0
fi

if [[ ! -d "$CC_SKILLS_DIR" ]]; then
  echo "ℹ️  Claude skills dir 없음: $CC_SKILLS_DIR — skip"
  exit 0
fi

echo "▶ Claude Code 스킬을 Codex canonical root로 동기화"

added=0
skipped=0
relinked=0
conflicts=0
invalid=0
loops=0
overrides=0

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
    /*) [[ "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$current")" == "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$src_path")" ]] ;;
    *) [[ "$(python3 -c 'import os,sys; print(os.path.realpath(os.path.join(os.path.dirname(sys.argv[1]), sys.argv[2])))' "$link_path" "$current")" == "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$src_path")" ]] ;;
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

is_allowed_codex_override() {
  case "$1" in
    setup-notify-hooks) return 0 ;;
    *) return 1 ;;
  esac
}

CODEX_REAL="$(real_path "$CODEX_SKILLS_DIR")"
AGENTS_SKILLS_DIR="$HOME/.agents/skills"
AGENTS_REAL=""
if [[ -e "$AGENTS_SKILLS_DIR" || -L "$AGENTS_SKILLS_DIR" ]]; then
  AGENTS_REAL="$(real_path "$AGENTS_SKILLS_DIR")"
fi

total=0

while IFS= read -r src; do
  s="$(basename "$src")"
  dst="$CODEX_SKILLS_DIR/$s"

  [[ "$s" == "." || "$s" == ".." ]] && continue
  ((total+=1))

  if [[ ! -f "$src/SKILL.md" ]]; then
    echo "  ⚠️  skip: $s — SKILL.md 없음"
    ((invalid+=1))
    continue
  fi

  src_real="$(real_path "$src")"
  if is_under "$src_real" "$CODEX_REAL" || { [[ -n "$AGENTS_REAL" ]] && is_under "$src_real" "$AGENTS_REAL"; }; then
    ((loops+=1))
    continue
  fi

  link_target="$(rel_link_target "$src" "$(dirname "$dst")")"

  if [[ -L "$dst" ]]; then
    if same_link_target "$dst" "$src" && [[ "$(readlink "$dst")" == "$link_target" ]]; then
      ((skipped+=1))
      continue
    fi
    rm "$dst"
    ln -s "$link_target" "$dst"
    echo "  ↻ relinked: $s"
    ((relinked+=1))
  elif [[ -e "$dst" ]]; then
    if [[ "$(real_path "$dst")" == "$src_real" ]]; then
      ((skipped+=1))
      continue
    fi
    if is_allowed_codex_override "$s"; then
      echo "  ↷ override: $s — Codex-compatible generated skill retained"
      ((overrides+=1))
      continue
    fi
    echo "  ⚠️  conflict: $s — Codex에 같은 이름의 실제 파일/디렉터리가 이미 존재"
    ((conflicts+=1))
    continue
  else
    ln -s "$link_target" "$dst"
    echo "  + added: $s"
    ((added+=1))
  fi
done < <(find -L "$CC_SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

echo ""
echo "  total: $total, added: $added, relinked: $relinked, skipped: $skipped, loops: $loops, overrides: $overrides, invalid: $invalid, conflicts: $conflicts"
