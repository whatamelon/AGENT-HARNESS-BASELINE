# tests/smoke.bats
load test_helper

@test "test_helper sets isolated HOME" {
  [[ "$HOME" == *"claude-sync-test."* ]]
  [ -d "$HOME/.config/claude-sync" ]
}

@test "jq is available" {
  run jq --version
  [ "$status" -eq 0 ]
}
