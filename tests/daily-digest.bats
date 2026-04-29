load test_helper

setup_yesterday_ledgers() {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  TS_YEST=$(date -v-1d +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  cat > "$SSOT/state/activity/홈맥에어.jsonl" <<EOF
{"ts":"$TS_YEST","host":"홈맥에어","type":"session_end","cwd":"/dev/x","duration_min":47,"commits":5}
EOF
  cat > "$SSOT/state/activity/회사맥프로.jsonl" <<EOF
{"ts":"$TS_YEST","host":"회사맥프로","type":"session_end","cwd":"/dev/y","duration_min":72,"commits":7}
EOF
}

@test "daily-digest --print shows yesterday summary" {
  setup_yesterday_ledgers
  run "$SSOT/bin/daily-digest.sh" --print
  [ "$status" -eq 0 ]
  [[ "$output" == *"두 맥북"* ]]
  [[ "$output" == *"홈맥에어"* ]]
  [[ "$output" == *"회사맥프로"* ]]
}

@test "daily-digest aggregates session counts" {
  setup_yesterday_ledgers
  run "$SSOT/bin/daily-digest.sh" --print
  [[ "$output" == *"1 sessions"* ]]
}

@test "daily-digest aggregates duration" {
  setup_yesterday_ledgers
  run "$SSOT/bin/daily-digest.sh" --print
  [[ "$output" == *"47"* ]]
  [[ "$output" == *"72"* ]]
}

@test "daily-digest handles empty ledgers gracefully" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  run "$SSOT/bin/daily-digest.sh" --print
  [ "$status" -eq 0 ]
  [[ "$output" == *"두 맥북"* ]]
}
