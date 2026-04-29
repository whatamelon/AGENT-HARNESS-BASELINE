# tests/ledger-query.bats
load test_helper

setup_two_ledgers() {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  mkdir -p "$SSOT/state/activity"

  # 동적 ts 생성 (테스트 실행 시각 기준 — 시기 민감 회피)
  # 모두 4시간 초과 과거 (since 4h 필터 밖이어야)
  TS_OLDEST=$(date -v-25H +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  TS_OLD=$(date -v-20H +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  TS_MID=$(date -v-12H +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  TS_RECENT=$(date -v-8H +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  export TS_OLDEST TS_OLD TS_MID TS_RECENT

  cat > "$SSOT/state/activity/홈맥에어.jsonl" <<EOF
{"ts":"$TS_OLDEST","host":"홈맥에어","type":"session_end","cwd":"/dev/foo","duration_min":15}
{"ts":"$TS_RECENT","host":"홈맥에어","type":"session_end","cwd":"/dev/lawblaw","duration_min":22}
EOF
  cat > "$SSOT/state/activity/회사맥프로.jsonl" <<EOF
{"ts":"$TS_OLD","host":"회사맥프로","type":"session_end","cwd":"/dev/lawblaw","duration_min":72}
{"ts":"$TS_MID","host":"회사맥프로","type":"commit","sha":"abc123"}
EOF
}

@test "ledger-query (no args) returns all events sorted by ts ascending" {
  setup_two_ledgers
  run "$SSOT/bin/ledger-query.sh"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | wc -l | tr -d ' ')
  [ "$count" = "4" ]
  first_ts=$(echo "$output" | head -1 | jq -r '.ts')
  [ "$first_ts" = "$TS_OLDEST" ]
}

@test "ledger-query --type filters by event type" {
  setup_two_ledgers
  run "$SSOT/bin/ledger-query.sh" --type session_end
  [ "$status" -eq 0 ]
  count=$(echo "$output" | wc -l | tr -d ' ')
  [ "$count" = "3" ]
}

@test "ledger-query --persona filters by host" {
  setup_two_ledgers
  run "$SSOT/bin/ledger-query.sh" --persona 회사맥프로
  [ "$status" -eq 0 ]
  count=$(echo "$output" | wc -l | tr -d ' ')
  [ "$count" = "2" ]
  hosts=$(echo "$output" | jq -r '.host' | sort -u)
  [ "$hosts" = "회사맥프로" ]
}

@test "ledger-query --since 4h filters recent events" {
  setup_two_ledgers
  ts=$(date -v-1H +%Y-%m-%dT%H:%M:%S%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')
  echo "{\"ts\":\"$ts\",\"host\":\"홈맥에어\",\"type\":\"wake\"}" >> "$SSOT/state/activity/홈맥에어.jsonl"
  run "$SSOT/bin/ledger-query.sh" --since 4h
  [ "$status" -eq 0 ]
  count=$(echo "$output" | wc -l | tr -d ' ')
  [ "$count" = "1" ]
  type=$(echo "$output" | jq -r '.type')
  [ "$type" = "wake" ]
}

@test "ledger-query handles missing ledger files gracefully" {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
  run "$SSOT/bin/ledger-query.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "ledger-query --format=text outputs human-readable lines" {
  setup_two_ledgers
  run "$SSOT/bin/ledger-query.sh" --format=text
  [ "$status" -eq 0 ]
  [[ "$output" == *"홈맥에어"* ]]
  [[ "$output" == *"회사맥프로"* ]]
}

@test "ledger-query --type with injection-attempt is treated as literal" {
  setup_two_ledgers
  # Injection payload — should be treated as literal type name (no events match)
  run "$SSOT/bin/ledger-query.sh" --type 'x" or true) | (.host // "x'
  [ "$status" -eq 0 ]
  # 매칭 없음 → 빈 출력
  [ -z "$output" ]
}
