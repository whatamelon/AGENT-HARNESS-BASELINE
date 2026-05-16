# tests/test_helper.bash
# 모든 .bats 파일이 load 하는 공통 헬퍼

# 격리된 임시 작업 디렉터리 생성 (각 테스트마다)
setup() {
  export TEST_TMPDIR=$(mktemp -d -t agent-harness-baseline-test.XXXXXX)
  export ORIG_HOME="$HOME"
  export HOME="$TEST_TMPDIR"
  mkdir -p "$HOME/.config/agent-harness-baseline/state/activity"
  mkdir -p "$HOME/.config/agent-harness-baseline/bin"
  # SSOT 경로 노출
  export SSOT="$HOME/.config/agent-harness-baseline"
  # 실제 bin 스크립트 임시 환경에 복사 (테스트 대상)
  if [[ -d "$ORIG_HOME/.config/agent-harness-baseline/bin" ]]; then
    cp "$ORIG_HOME/.config/agent-harness-baseline/bin/"*.sh "$SSOT/bin/" 2>/dev/null || true
  fi
}

teardown() {
  export HOME="$ORIG_HOME"
  rm -rf "$TEST_TMPDIR"
}

# JSONL 한 줄 파싱 — assertion에 사용
jsonl_field() {
  local file="$1" line_num="$2" field="$3"
  sed -n "${line_num}p" "$file" | jq -r ".$field"
}
