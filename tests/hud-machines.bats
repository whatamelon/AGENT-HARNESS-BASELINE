# tests/hud-machines.bats
load test_helper

setup_persona_and_ledgers() {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity" "$SSOT/state/hud-cache"
  TS_5MIN=$(date -v-5M +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  cat > "$SSOT/state/activity/회사맥프로.jsonl" <<EOF
{"ts":"$TS_5MIN","host":"회사맥프로","type":"session_end","cwd":"/dev/lawblaw","duration_min":22}
EOF
  export TS_5MIN
}

@test "hud-machines --format=line includes both persona names" {
  setup_persona_and_ledgers
  run "$SSOT/bin/hud-machines.sh" --format=line
  [ "$status" -eq 0 ]
  [[ "$output" == *"홈맥에어"* ]]
  [[ "$output" == *"회사맥프로"* ]]
}

@test "hud-machines self machine has solid dot" {
  setup_persona_and_ledgers
  run "$SSOT/bin/hud-machines.sh" --format=line
  [[ "$output" == *"🏠 홈맥에어 ●"* ]]
}

@test "hud-machines other machine 5min ago shows lightning" {
  setup_persona_and_ledgers
  run "$SSOT/bin/hud-machines.sh" --format=line
  [[ "$output" == *"⚡"* ]]
  [[ "$output" == *"5"* ]]
}

@test "hud-machines other machine under 2min shows sparkle" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  TS_NOW=$(date -v-1M +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  echo "{\"ts\":\"$TS_NOW\",\"host\":\"회사맥프로\",\"type\":\"wake\"}" > "$SSOT/state/activity/회사맥프로.jsonl"
  run "$SSOT/bin/hud-machines.sh" --format=line
  [[ "$output" == *"✨방금"* ]]
}

@test "hud-machines other machine 7+ days shows new moon" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  TS_OLD=$(date -v-10d +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  echo "{\"ts\":\"$TS_OLD\",\"host\":\"회사맥프로\",\"type\":\"wake\"}" > "$SSOT/state/activity/회사맥프로.jsonl"
  run "$SSOT/bin/hud-machines.sh" --format=line
  [[ "$output" == *"🌑"* ]]
}

@test "hud-machines other machine never seen handles gracefully" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  run "$SSOT/bin/hud-machines.sh" --format=line
  [ "$status" -eq 0 ]
  [[ "$output" == *"홈맥에어"* ]]
}

@test "hud-machines uses cache within 5s TTL" {
  setup_persona_and_ledgers
  run "$SSOT/bin/hud-machines.sh" --format=line
  cache_file="$SSOT/state/hud-cache/홈맥에어.line.txt"
  [ -f "$cache_file" ]
  first_output="$output"
  run "$SSOT/bin/hud-machines.sh" --format=line
  [ "$output" = "$first_output" ]
}

@test "hud-machines bypasses cache with --no-cache" {
  setup_persona_and_ledgers
  "$SSOT/bin/hud-machines.sh" --format=line >/dev/null
  cache_file="$SSOT/state/hud-cache/홈맥에어.line.txt"
  cache_mtime_before=$(stat -f %m "$cache_file")
  sleep 1
  run "$SSOT/bin/hud-machines.sh" --format=line --no-cache
  [ "$status" -eq 0 ]
  cache_mtime_after=$(stat -f %m "$cache_file")
  [ "$cache_mtime_after" -gt "$cache_mtime_before" ]
}

@test "hud-machines --format=detail shows last session info" {
  setup_persona_and_ledgers
  run "$SSOT/bin/hud-machines.sh" --format=detail
  [ "$status" -eq 0 ]
  [[ "$output" == *"홈맥에어"* ]]
  [[ "$output" == *"회사맥프로"* ]]
  [[ "$output" == *"lawblaw"* ]]
}

@test "hud-machines --format=detail counts today commits" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  TS_NOW=$(date +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  cat > "$SSOT/state/activity/홈맥에어.jsonl" <<EOF
{"ts":"$TS_NOW","host":"홈맥에어","type":"commit","sha":"abc1"}
{"ts":"$TS_NOW","host":"홈맥에어","type":"commit","sha":"abc2"}
{"ts":"$TS_NOW","host":"홈맥에어","type":"commit","sha":"abc3"}
EOF
  run "$SSOT/bin/hud-machines.sh" --format=detail
  [[ "$output" == *"오늘 commits: 3"* ]]
}

@test "hud-machines --format=detail handles empty other ledger" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"
  run "$SSOT/bin/hud-machines.sh" --format=detail
  [ "$status" -eq 0 ]
  [[ "$output" == *"홈맥에어"* ]]
}

@test "hud-machines --format=line prepends flash when state/hud-flash.txt < 5s old" {
  setup_persona_and_ledgers
  echo "lawblaw 끝!" > "$SSOT/state/hud-flash.txt"
  run "$SSOT/bin/hud-machines.sh" --format=line --no-cache
  [ "$status" -eq 0 ]
  [[ "$output" == *"✨"* ]]
  [[ "$output" == *"lawblaw 끝"* ]]
}

@test "hud-machines --format=line ignores flash older than 5s" {
  setup_persona_and_ledgers
  echo "stale flash" > "$SSOT/state/hud-flash.txt"
  # 6초 이전 mtime
  touch -A -10 "$SSOT/state/hud-flash.txt" 2>/dev/null || touch -t "$(date -v-1M +%Y%m%d%H%M)" "$SSOT/state/hud-flash.txt"
  run "$SSOT/bin/hud-machines.sh" --format=line --no-cache
  [[ "$output" != *"stale flash"* ]]
}
