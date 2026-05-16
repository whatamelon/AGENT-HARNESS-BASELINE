#!/usr/bin/env bash
# safe-omc-cache-trim.sh — OMC 플러그인 캐시를 안전하게 정리한다.
#
# 왜 필요한가:
#   OMC/OMX `/doctor` 의 "keep only latest, rm old" 캐시 트림은 위험하다.
#   Claude Code 플러그인 매니저는 ~/.claude/plugins/installed_plugins.json 의
#   installPath 로 oh-my-claudecode 의 특정 버전 디렉토리에 핀한다.
#   `omc update`(CLI) 는 자체 캐시만 올리고 이 레코드는 미갱신한다.
#   라이브 세션은 시작 시점의 핀 버전 디렉토리를 $CLAUDE_PLUGIN_ROOT 로
#   바인딩하므로, 핀/사용 중 버전을 지우면 그 세션의 플러그인 훅이 ENOENT 로
#   전부 죽는다(2026-05-16 실제 발생: 4.13.5/4.13.7 삭제 → 훅 실패).
#
# 보장:
#   1. installed_plugins.json 이 핀한 oh-my-claudecode 버전은 절대 rm 하지 않는다.
#   2. 핀됐지만 최신 아님 → 최신으로 향하는 심링크 shim 으로 대체(디스크↓, 경로 유지).
#   3. 최신 실디렉토리 1개 항상 보존.
#   4. 핀 안 된 + 최신 아님 인 실디렉토리만 삭제.
#   멱등 — 반복 실행해도 같은 종착 상태. macOS bash 3.2 호환.
#
# 사용: safe-omc-cache-trim.sh [--dry-run]

set -eo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CACHE_DIR="$CLAUDE_DIR/plugins/cache/omc/oh-my-claudecode"
REGISTRY="$CLAUDE_DIR/plugins/installed_plugins.json"

[ -d "$CACHE_DIR" ] || { echo "no OMC cache dir: $CACHE_DIR"; exit 0; }

# 핀된 oh-my-claudecode 버전 (installed_plugins.json installPath)
pinned=""
if [ -f "$REGISTRY" ]; then
  pinned=$(grep -oE 'oh-my-claudecode/[^"]+' "$REGISTRY" 2>/dev/null \
            | sed 's|oh-my-claudecode/||' | sort -u | tr '\n' ' ')
fi

# 실디렉토리(심링크 제외) 버전, semver 정렬
real_versions=""
while IFS= read -r d; do
  [ -n "$d" ] && real_versions="$real_versions $(basename "$d")"
done < <(find "$CACHE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V)
real_versions=$(echo "$real_versions" | xargs 2>/dev/null || true)

[ -z "$real_versions" ] && { echo "no real version dirs (only shims?) — nothing to trim"; exit 0; }

newest=""
for v in $real_versions; do newest="$v"; done   # semver-sorted 마지막 = 최신

echo "newest real version: $newest"
echo "pinned versions: ${pinned:-(none)}"

is_pinned() {
  case " $pinned " in *" $1 "*) return 0;; *) return 1;; esac
}

# 1) 핀됐지만 최신 아님 → shim 보장
for p in $pinned; do
  [ -z "$p" ] && continue
  [ "$p" = "$newest" ] && continue
  target="$CACHE_DIR/$p"
  if [ -L "$target" ]; then
    continue
  elif [ -d "$target" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then echo "[dry] replace real $p -> symlink $newest"
    else rm -rf "$target"; ln -s "$newest" "$target"; echo "shim: $p -> $newest"; fi
  else
    if [ "$DRY_RUN" -eq 1 ]; then echo "[dry] create shim $p -> $newest"
    else ln -s "$newest" "$target"; echo "shim(new): $p -> $newest"; fi
  fi
done

# 2) 핀 안 됨 + 최신 아님 실디렉토리만 삭제
for v in $real_versions; do
  [ "$v" = "$newest" ] && continue
  if is_pinned "$v"; then echo "keep (pinned): $v"; continue; fi
  if [ "$DRY_RUN" -eq 1 ]; then echo "[dry] rm unpinned old: $v"
  else rm -rf "${CACHE_DIR:?}/$v"; echo "removed unpinned old: $v"; fi
done

echo "done. newest kept: $newest ; pins preserved as real/shim."
