#!/usr/bin/env bash
# relink.sh — 새 디렉터리 추가됐을 때 다시 링크. install.sh 의 symlink 부분만 재실행.
set -euo pipefail
exec "$(dirname "$0")/install.sh"
