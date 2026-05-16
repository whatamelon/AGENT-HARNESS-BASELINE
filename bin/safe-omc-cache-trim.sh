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
# 이 스크립트의 보장:
#   1. installed_plugins.json 이 핀한 모든 oh-my-claudecode 버전은 절대 rm 하지 않는다.
#   2. 핀됐지만 최신이 아닌 버전은 (실디렉토리 대신) 최신으로 향하는 심링크 shim 으로
#      대체해 디스크는 줄이되 경로 해석은 깨지 않는다.
#   3. 최신 실디렉토리 1개는 항상 보존한다.
#   4. 핀되지 않은 구버전 실디렉토리만 삭제 대상.
#   멱등 — 반복 실행해도 같은 종착 상태.
#
# 사용: safe-omc-cache-trim.sh [--dry-run]

set -euo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CACHE_DIR="$CLAUDE_DIR/plugins/cache/omc/oh-my-claudecode"
REGISTRY="$CLAUDE_DIR/plugins/installed_plugins.json"

[[ -d "$CACHE_DIR" ]] || { echo "no OMC cache dir: $CACHE_DIR"; exit 0; }

# 핀된 oh-my-claudecode 버전들 (installed_plugins.json installPath 기준)
pinned=()
if [[ -f "$REGISTRY" ]]; then
  while IFS= read -r v; do
    [[ -n "$v" ]] && pinned+=("$v")
  done < <(grep -oE 'oh-my-claudecode/[^"]+' "$REGISTRY" 2>/dev/null \
            | sed 's|oh-my-claudecode/||' | sort -u)
fi

# 실디렉토리(심링크 아님) 버전 목록, semver 정렬
real_versions=()
while IFS= read -r d; do
  real_versions+=("$(basename "$d")")
done < <(find "$CACHE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V)

[[ ${#real_versions[@]} -eq 0 ]] && { echo "no real version dirs"; exit 0; }

newest="${real_versions[-1]}"
echo "newest real version: $newest"
echo "pinned versions: ${pinned[*]:-(none)}"

is_pinned() { local x="$1"; for p in "${pinned[@]:-}"; do [[ "$p" == "$x" ]] && return 0; done; return 1; }

# 1) 핀됐지만 캐시에 없는/구버전 실디렉토리인 핀 → 최신으로 심링크 shim 보장
for p in "${pinned[@]:-}"; do
  [[ -z "$p" || "$p" == "$newest" ]] && continue
  target="$CACHE_DIR/$p"
  if [[ -L "$target" ]]; then
    continue                       # 이미 shim
  elif [[ -d "$target" ]]; then
    # 핀된 구버전이 실디렉토리 → shim 으로 대체 (디스크 절약, 경로 유지)
    if [[ $DRY_RUN -eq 1 ]]; then echo "[dry] replace real $p -> symlink $newest"
    else rm -rf "$target"; ln -s "$newest" "$target"; echo "shim: $p -> $newest"; fi
  else
    if [[ $DRY_RUN -eq 1 ]]; then echo "[dry] create shim $p -> $newest"
    else ln -s "$newest" "$target"; echo "shim(new): $p -> $newest"; fi
  fi
done

# 2) 핀되지 않은 + 최신 아님 인 실디렉토리만 삭제
for v in "${real_versions[@]}"; do
  [[ "$v" == "$newest" ]] && continue
  if is_pinned "$v"; then
    echo "keep (pinned, handled as shim above): $v"; continue
  fi
  if [[ $DRY_RUN -eq 1 ]]; then echo "[dry] rm unpinned old: $v"
  else rm -rf "${CACHE_DIR:?}/$v"; echo "removed unpinned old: $v"; fi
done

echo "done. newest kept: $newest ; pins preserved as real/shim."
