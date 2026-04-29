# tests/ledger-append.bats
load test_helper

setup_persona() {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
}

@test "ledger-append fails without event type" {
  setup_persona
  run "$SSOT/bin/ledger-append.sh"
  [ "$status" -ne 0 ]
}

@test "ledger-append creates jsonl file with single event" {
  setup_persona
  run "$SSOT/bin/ledger-append.sh" "session_start"
  [ "$status" -eq 0 ]
  ledger="$SSOT/state/activity/홈맥에어.jsonl"
  [ -f "$ledger" ]
  [ $(wc -l < "$ledger") -eq 1 ]
  type=$(jq -r '.type' "$ledger")
  [ "$type" = "session_start" ]
  host=$(jq -r '.host' "$ledger")
  [ "$host" = "홈맥에어" ]
}

@test "ledger-append parses key=value pairs into JSON fields" {
  setup_persona
  run "$SSOT/bin/ledger-append.sh" "session_end" \
    "cwd=/dev/lawblaw" "duration_min=22" "commits=3"
  [ "$status" -eq 0 ]
  ledger="$SSOT/state/activity/홈맥에어.jsonl"
  cwd=$(jq -r '.cwd' "$ledger")
  [ "$cwd" = "/dev/lawblaw" ]
  duration=$(jq -r '.duration_min' "$ledger")
  [ "$duration" = "22" ]
  commits=$(jq -r '.commits' "$ledger")
  [ "$commits" = "3" ]
}

@test "ledger-append appends (does not overwrite)" {
  setup_persona
  "$SSOT/bin/ledger-append.sh" "wake" >/dev/null
  "$SSOT/bin/ledger-append.sh" "session_start" >/dev/null
  "$SSOT/bin/ledger-append.sh" "session_end" "duration_min=10" >/dev/null
  ledger="$SSOT/state/activity/홈맥에어.jsonl"
  [ $(wc -l < "$ledger") -eq 3 ]
  third=$(sed -n '3p' "$ledger" | jq -r '.type')
  [ "$third" = "session_end" ]
}

@test "ledger-append timestamp is ISO8601" {
  setup_persona
  run "$SSOT/bin/ledger-append.sh" "wake"
  ledger="$SSOT/state/activity/홈맥에어.jsonl"
  ts=$(jq -r '.ts' "$ledger")
  [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:?[0-9]{2}$ ]]
}

@test "ledger-append handles values with spaces (quoted)" {
  setup_persona
  run "$SSOT/bin/ledger-append.sh" "commit" "message=fix(auth): SSO 토큰 검증"
  [ "$status" -eq 0 ]
  ledger="$SSOT/state/activity/홈맥에어.jsonl"
  msg=$(jq -r '.message' "$ledger")
  [ "$msg" = "fix(auth): SSO 토큰 검증" ]
}
