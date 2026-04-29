#!/usr/bin/env bats
# tests/notify-session-end.bats

load test_helper

setup_persona_and_session() {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  TS_START=$(date -v-5M +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  echo "{\"ts\":\"$TS_START\",\"host\":\"홈맥에어\",\"type\":\"session_start\",\"cwd\":\"/tmp/proj\"}" \
    > "$SSOT/state/activity/홈맥에어.jsonl"
}

@test "notify-session-end skips short session (<3min, 0 commits)" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  TS_START=$(date -v-1M +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  echo "{\"ts\":\"$TS_START\",\"host\":\"홈맥에어\",\"type\":\"session_start\",\"cwd\":\"/tmp/proj\"}" \
    > "$SSOT/state/activity/홈맥에어.jsonl"

  DRY_RUN=1 run "$SSOT/bin/notify-session-end.sh" "/tmp/proj"
  [ "$status" -eq 0 ]
  count=$(grep -c "session_end" "$SSOT/state/activity/홈맥에어.jsonl" 2>/dev/null; true)
  [ "$count" = "0" ]
}

@test "notify-session-end runs full notify on long session (>=3min)" {
  setup_persona_and_session
  DRY_RUN=1 run "$SSOT/bin/notify-session-end.sh" "/tmp/proj"
  [ "$status" -eq 0 ]
}

@test "notify-session-end recognizes commit-only sessions" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  TS_START=$(date -v-1M +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  TS_NOW=$(date +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  cat > "$SSOT/state/activity/홈맥에어.jsonl" <<EOF
{"ts":"$TS_START","host":"홈맥에어","type":"session_start","cwd":"/tmp/proj"}
{"ts":"$TS_NOW","host":"홈맥에어","type":"commit","sha":"abc1"}
EOF
  DRY_RUN=1 run "$SSOT/bin/notify-session-end.sh" "/tmp/proj"
  [ "$status" -eq 0 ]
}

@test "notify-session-end handles missing session_start" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  DRY_RUN=1 run "$SSOT/bin/notify-session-end.sh" "/tmp/proj"
  [ "$status" -eq 0 ]
}

@test "notify-session-end appends session_end event when meaningful" {
  setup_persona_and_session
  run "$SSOT/bin/notify-session-end.sh" "/tmp/proj"
  [ "$status" -eq 0 ]
  count=$(grep -c "session_end" "$SSOT/state/activity/홈맥에어.jsonl")
  [ "$count" -ge "1" ]
}
