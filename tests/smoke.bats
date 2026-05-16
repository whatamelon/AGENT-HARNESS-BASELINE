# tests/smoke.bats
load test_helper

@test "test_helper sets isolated HOME" {
  [[ "$HOME" == *"agent-harness-baseline-test."* ]]
  [ -d "$HOME/.config/agent-harness-baseline" ]
}

@test "jq is available" {
  run jq --version
  [ "$status" -eq 0 ]
}
