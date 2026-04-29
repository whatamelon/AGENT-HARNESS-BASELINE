load test_helper

setup_persona() {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
}

@test "hud-catchup silent if no last-prompt-ts" {
  setup_persona
  run "$SSOT/bin/hud-catchup.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hud-catchup silent if last-prompt < 4h ago" {
  setup_persona
  date +%s > "$SSOT/state/last-prompt-ts.txt"
  run "$SSOT/bin/hud-catchup.sh"
  [ -z "$output" ]
}

@test "hud-catchup shows other machine activity if last-prompt >= 4h ago" {
  setup_persona
  echo "$(( $(date +%s) - 18000 ))" > "$SSOT/state/last-prompt-ts.txt"
  # last_epoch(-18000s) 직후 활동 — since 필터(last_epoch 기준) 통과
  TS_AFTER=$(date -r $(( $(date +%s) - 17000 )) +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  echo "{\"ts\":\"$TS_AFTER\",\"host\":\"회사맥프로\",\"type\":\"session_end\",\"cwd\":\"/dev/lawblaw\",\"duration_min\":22}" \
    > "$SSOT/state/activity/회사맥프로.jsonl"

  run "$SSOT/bin/hud-catchup.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"홈맥에어 깨어남"* ]]
  [[ "$output" == *"회사맥프로"* ]]
  [[ "$output" == *"lawblaw"* ]]
}

@test "hud-catchup updates last-prompt-ts after display" {
  setup_persona
  echo "$(( $(date +%s) - 18000 ))" > "$SSOT/state/last-prompt-ts.txt"
  # last_epoch(-18000s) 직후 활동 — since 필터(last_epoch 기준) 통과
  TS_AFTER=$(date -r $(( $(date +%s) - 17000 )) +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  echo "{\"ts\":\"$TS_AFTER\",\"host\":\"회사맥프로\",\"type\":\"wake\"}" \
    > "$SSOT/state/activity/회사맥프로.jsonl"

  run "$SSOT/bin/hud-catchup.sh"
  ts_after=$(cat "$SSOT/state/last-prompt-ts.txt")
  ts_now=$(date +%s)
  diff=$(( ts_now - ts_after ))
  [ "$diff" -lt "5" ]
}
