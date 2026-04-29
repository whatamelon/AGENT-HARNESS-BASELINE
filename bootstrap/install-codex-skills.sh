#!/usr/bin/env bash
# install-codex-skills.sh
# claude-sync에 보관된 CC 전용 스킬을 ~/.codex/skills/ 로 심링크해서
# Codex CLI가 동일한 스킬을 인식하도록 한다.
#
# - 멱등(idempotent): 이미 올바른 심링크면 skip, 깨진 링크는 재생성
# - 회사 맥북 부트스트랩 + 평소 sync 양쪽에서 호출 가능

set -euo pipefail

CC_SKILLS_DIR="$HOME/.config/claude-sync/claude/skills"
CODEX_SKILLS_DIR="$HOME/.codex/skills"

# CC 전용(=claude-sync 안 실제 디렉터리로 보관) 스킬 자동 탐지:
# claude-sync/claude/skills 안에서 심링크가 아닌 실제 디렉터리만 추출
# (macOS 기본 bash 3.2 호환을 위해 mapfile 대신 while read 사용)
CC_ONLY=()
while IFS= read -r dir; do
  CC_ONLY+=("$(basename "$dir")")
done < <(find "$CC_SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d -not -path "$CC_SKILLS_DIR")

if [[ ${#CC_ONLY[@]} -eq 0 ]]; then
  echo "ℹ️  CC 전용 스킬 없음 — skip"
  exit 0
fi

if [[ ! -d "$CODEX_SKILLS_DIR" ]]; then
  echo "ℹ️  ~/.codex/skills 없음 — Codex 미설치이거나 초기화 전. skip"
  exit 0
fi

echo "▶ ${#CC_ONLY[@]}개 CC 전용 스킬을 Codex로 노출"

added=0
skipped=0
relinked=0

for s in "${CC_ONLY[@]}"; do
  src="$CC_SKILLS_DIR/$s"
  dst="$CODEX_SKILLS_DIR/$s"

  if [[ -L "$dst" ]]; then
    current=$(readlink "$dst")
    if [[ "$current" == "$src" ]]; then
      ((skipped++))
      continue
    fi
    rm "$dst"
    ln -s "$src" "$dst"
    echo "  ↻ relinked: $s"
    ((relinked++))
  elif [[ -e "$dst" ]]; then
    echo "  ⚠️  skip: $s — 같은 이름의 실제 파일/디렉터리가 이미 존재"
    continue
  else
    ln -s "$src" "$dst"
    echo "  + added: $s"
    ((added++))
  fi
done

echo ""
echo "  added: $added, relinked: $relinked, skipped: $skipped"
