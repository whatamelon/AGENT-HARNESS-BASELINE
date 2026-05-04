#!/usr/bin/env bash
# install-shared-skills.sh
# claude-sync/agents/skill-lock.json 을 권위 자료로 Codex canonical
# ~/.codex/skills/ 를 재구성한다. 호환성을 위해 ~/.agents/skills 는
# ~/.codex/skills 로 향하는 symlink 로 유지한다.
#
# - lock 파일에 기록된 GitHub repo들에서 스킬 디렉터리만 추출해 복사
# - 멱등(idempotent): 이미 SKILL.md가 있는 스킬은 skip
# - 새 머신 부트스트랩 후 한 번 돌리면 Claude Code와 Codex가 같은 스킬 풀을 보게 됨
# - 회사 맥북에서도 동일하게 작동
#
# 의존성: jq, git

set -euo pipefail

LOCK="$HOME/.config/claude-sync/agents/skill-lock.json"
AGENTS_DIR="$HOME/.agents"
CODEX_SKILLS_DIR="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
SKILLS_DIR="$CODEX_SKILLS_DIR"
CACHE="$HOME/.cache/claude-sync/skill-sources"

# 의존성 체크
for cmd in jq git; do
  command -v "$cmd" >/dev/null || { echo "❌ '$cmd' 필요. 'brew install $cmd' 실행"; exit 1; }
done

[[ -f "$LOCK" ]] || { echo "❌ $LOCK 없음"; exit 1; }

mkdir -p "$SKILLS_DIR" "$CACHE" "$AGENTS_DIR"

# Older Codex setups loaded ~/.agents/skills directly. Modern Codex/OMX uses
# ~/.codex/skills. Keep the legacy path as a symlink to avoid duplicate skill
# roots while preserving compatibility with tools that still probe ~/.agents.
if [[ -L "$AGENTS_DIR/skills" ]]; then
  if [[ "$(readlink "$AGENTS_DIR/skills")" != "$SKILLS_DIR" ]]; then
    rm "$AGENTS_DIR/skills"
    ln -s "$SKILLS_DIR" "$AGENTS_DIR/skills"
  fi
elif [[ -e "$AGENTS_DIR/skills" ]]; then
  if [[ -z "$(find "$AGENTS_DIR/skills" -mindepth 1 -maxdepth 1 2>/dev/null | head -1)" ]]; then
    rm -rf "$AGENTS_DIR/skills"
  else
    backup="$AGENTS_DIR/skills.archived-$(date +%Y%m%d-%H%M%S)"
    mv "$AGENTS_DIR/skills" "$backup"
    echo "  ↪ archived legacy ~/.agents/skills -> $backup"
  fi
  ln -s "$SKILLS_DIR" "$AGENTS_DIR/skills"
else
  ln -s "$SKILLS_DIR" "$AGENTS_DIR/skills"
fi

# 1) 모든 sourceUrl 추출 → 캐시에 shallow clone (없을 때만)
echo "▶ source repo 캐시 점검"
while IFS= read -r url; do
  # URL → 디렉터리 이름 (예: github.com/wshobson/agents.git → wshobson_agents)
  slug=$(echo "$url" | sed -E 's|https://github.com/||; s|\.git$||; s|/|_|g')
  dest="$CACHE/$slug"
  if [[ -d "$dest/.git" ]]; then
    echo "  • cache hit: $slug"
  else
    echo "  ↓ cloning: $url"
    git clone --depth=1 --quiet "$url" "$dest"
  fi
done < <(jq -r '[.skills | to_entries[] | .value.sourceUrl] | unique | .[]' "$LOCK")

echo ""
echo "▶ 스킬 동기화 (lock 기준)"

added=0
skipped=0
missing=0

# 2) lock 순회 → 각 스킬 디렉터리 복사
while IFS=$'\t' read -r name url skill_path; do
  dst="$SKILLS_DIR/$name"

  if [[ -f "$dst/SKILL.md" ]]; then
    ((skipped++))
    continue
  fi

  slug=$(echo "$url" | sed -E 's|https://github.com/||; s|\.git$||; s|/|_|g')
  src_dir="$CACHE/$slug/$(dirname "$skill_path")"

  if [[ ! -f "$src_dir/SKILL.md" ]]; then
    echo "  ✗ missing in source: $name ($skill_path)"
    ((missing++))
    continue
  fi

  rm -rf "$dst"
  cp -R "$src_dir" "$dst"
  ((added++))
done < <(jq -r '.skills | to_entries[] | "\(.key)\t\(.value.sourceUrl)\t\(.value.skillPath)"' "$LOCK")

# 3) lock 파일 사본을 ~/.agents/.skill-lock.json 로 동기화
cp "$LOCK" "$AGENTS_DIR/.skill-lock.json"

echo ""
echo "  added: $added, skipped: $skipped, missing: $missing"
echo "  skills: $SKILLS_DIR"
echo "  legacy: $AGENTS_DIR/skills -> $SKILLS_DIR"
echo "  cache: $CACHE (재실행 시 git pull 안 함 — 갱신은 'rm -rf $CACHE' 후 재실행)"
