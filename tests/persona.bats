# tests/persona.bats
load test_helper

@test "persona.sh --init creates .machine.json with default for unknown hostname" {
  HOSTNAME_OVERRIDE="random-host" run "$SSOT/bin/persona.sh" --init
  [ "$status" -eq 0 ]
  [ -f "$SSOT/.machine.json" ]
  result=$(jq -r '.persona' "$SSOT/.machine.json")
  [ "$result" = "홈맥에어" ]
}

@test "persona.sh --init detects MacBook Air as home persona" {
  HOSTNAME_OVERRIDE="Dennys-MacBook-Air" run "$SSOT/bin/persona.sh" --init
  [ "$status" -eq 0 ]
  result=$(jq -r '.persona' "$SSOT/.machine.json")
  [ "$result" = "홈맥에어" ]
  emoji=$(jq -r '.emoji' "$SSOT/.machine.json")
  [ "$emoji" = "🏠" ]
}

@test "persona.sh --init detects MacBook Pro as work persona" {
  HOSTNAME_OVERRIDE="Dennys-MacBook-Pro" run "$SSOT/bin/persona.sh" --init
  [ "$status" -eq 0 ]
  result=$(jq -r '.persona' "$SSOT/.machine.json")
  [ "$result" = "회사맥프로" ]
  color=$(jq -r '.color' "$SSOT/.machine.json")
  [ "$color" = "#0969DA" ]
}

@test "persona.sh (no args) returns persona name from .machine.json" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  run "$SSOT/bin/persona.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "홈맥에어" ]
}

@test "persona.sh --json returns full JSON" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  run "$SSOT/bin/persona.sh" --json
  [ "$status" -eq 0 ]
  result=$(echo "$output" | jq -r '.persona')
  [ "$result" = "홈맥에어" ]
}

@test "persona.sh --other returns the other persona" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  run "$SSOT/bin/persona.sh" --other
  [ "$status" -eq 0 ]
  [ "$output" = "회사맥프로" ]
}

@test "persona.sh fails gracefully when .machine.json missing and not --init" {
  run "$SSOT/bin/persona.sh"
  [ "$status" -ne 0 ]
}
