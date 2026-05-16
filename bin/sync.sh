#!/usr/bin/env bash
# sync.sh — git pull → 변경 있으면 자동 commit/push
# 사용법:
#   sync.sh                기본 (pull → commit → push)
#   sync.sh --immediate    pull 스킵, commit/push만 (Stop hook 등에서 호출)
set -uo pipefail

SSOT="$HOME/.config/agent-harness-baseline"
cd "$SSOT" || exit 1

# 사용자가 ahb-pause 로 lock 걸어둔 동안 sync 차단 (사람-데몬 race 방지).
# ahb-resume 또는 .sync-paused 직접 삭제로 해제.
if [[ -f "$SSOT/.sync-paused" ]]; then
  exit 0
fi

mode="${1:-full}"

# 원격 없으면 스킵
git remote get-url origin >/dev/null 2>&1 || {
  # --immediate 모드는 원격 없어도 로컬 commit만 수행
  if [[ "$mode" == "--immediate" ]]; then
    if [[ -n "$(git status --porcelain)" ]]; then
      git add .
      git commit -m "auto: $(hostname -s) $(date +%FT%T%z)" --quiet
    fi
    exit 0
  fi
  exit 0
}

BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo main)

if [[ "$mode" != "--immediate" ]]; then
  # full mode: pull 먼저
  git fetch --quiet origin "$BRANCH" 2>&1 || exit 1
  git pull --rebase --autostash --quiet origin "$BRANCH" 2>&1 || exit 1

  # pull 로 rules/MEMORY 변경이 들어왔다면 ~/AGENTS.md 갱신
  "$SSOT/bin/rebuild-agents-md.sh" --quiet 2>/dev/null || true

  # Claude Code ↔ Codex 공유 표면도 자동 갱신.
  # --immediate 에서는 codex-bridge --push 가 다시 sync.sh 를 부르므로 실행하지 않는다.
  if [[ "${AGENT_HARNESS_BASELINE_SKIP_CODEX_BRIDGE:-0}" != "1" && -x "$SSOT/bin/codex-bridge.sh" ]]; then
    AGENT_HARNESS_BASELINE_SKIP_CODEX_BRIDGE=1 "$SSOT/bin/codex-bridge.sh" --quiet 2>/tmp/agent-harness-baseline-codex-bridge.err.log || true
  fi
fi

# Push 할 변경 있는지 (양 모드 공통)
if [[ -n "$(git status --porcelain)" ]]; then
  git add .
  git commit -m "auto: $(hostname -s) $(date +%FT%T%z)" --quiet
  git push --quiet 2>&1 || true
fi
