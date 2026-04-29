#!/usr/bin/env bats
# tests/greet.bats

load test_helper

setup_persona() {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
}

@test "greet --skip marks greeted without playing sequence" {
  setup_persona
  echo '{"completed":true,"greeted":false}' > "$SSOT/state/wizard-state.json"
  run "$SSOT/bin/greet.sh" --skip
  [ "$status" -eq 0 ]
  greeted=$(jq -r '.greeted' "$SSOT/state/wizard-state.json")
  [ "$greeted" = "true" ]
  [ -z "$output" ]
}

@test "greet (default) silent if not completed" {
  setup_persona
  echo '{"completed":false,"greeted":false}' > "$SSOT/state/wizard-state.json"
  run "$SSOT/bin/greet.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "greet (default) silent if already greeted" {
  setup_persona
  echo '{"completed":true,"greeted":true}' > "$SSOT/state/wizard-state.json"
  run "$SSOT/bin/greet.sh"
  [ -z "$output" ]
}

@test "greet (default) plays sequence and marks greeted when conditions met" {
  setup_persona
  echo '{"completed":true,"greeted":false}' > "$SSOT/state/wizard-state.json"
  TS_RECENT=$(date -v-30M +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  echo "{\"ts\":\"$TS_RECENT\",\"host\":\"회사맥프로\",\"type\":\"session_end\",\"cwd\":\"/dev/lawblaw\",\"duration_min\":22,\"summary\":\"fix(auth)\"}" \
    > "$SSOT/state/activity/회사맥프로.jsonl"
  FAST_GREET=1 run "$SSOT/bin/greet.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"홈맥에어"* ]]
  [[ "$output" == *"안녕"* ]] || [[ "$output" == *"회사맥프로"* ]]
  greeted=$(jq -r '.greeted' "$SSOT/state/wizard-state.json")
  [ "$greeted" = "true" ]
}

@test "greet --replay plays regardless of greeted state" {
  setup_persona
  echo '{"completed":true,"greeted":true}' > "$SSOT/state/wizard-state.json"
  FAST_GREET=1 run "$SSOT/bin/greet.sh" --replay
  [ "$status" -eq 0 ]
  [[ "$output" == *"홈맥에어"* ]] || [[ "$output" == *"회사맥프로"* ]]
}

@test "greet handles missing wizard-state.json gracefully" {
  setup_persona
  rm -f "$SSOT/state/wizard-state.json"
  run "$SSOT/bin/greet.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
