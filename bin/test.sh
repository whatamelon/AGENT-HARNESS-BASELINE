#!/usr/bin/env bash
# bin/test.sh — 모든 bats 테스트 실행
set -euo pipefail
SSOT="$HOME/.config/agent-harness-baseline"
cd "$SSOT" || exit 1

if ! command -v bats >/dev/null; then
  echo "❌ bats 미설치 — 'brew install bats-core'"
  exit 1
fi

bats tests/
