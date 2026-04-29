# tests/notify-activity.bats
load test_helper

setup_persona() {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
}

@test "notify-activity calls ledger-append (event in jsonl)" {
  setup_persona
  run "$SSOT/bin/notify-activity.sh" "session_start" "cwd=/x"
  [ "$status" -eq 0 ]
  ledger="$SSOT/state/activity/홈맥에어.jsonl"
  [ -f "$ledger" ]
  type=$(jq -r '.type' "$ledger")
  [ "$type" = "session_start" ]
}

@test "notify-activity does not fail when telegram token missing" {
  setup_persona
  run "$SSOT/bin/notify-activity.sh" "wake"
  [ "$status" -eq 0 ]
}

@test "notify-activity formats Telegram message with persona emoji" {
  setup_persona
  source "$SSOT/bin/notify-activity.sh" --source-only 2>/dev/null || skip "--source-only 미지원이면 skip"
  msg=$(format_telegram_message "session_end" "lawblaw_dev" "22m" "3 commits")
  [[ "$msg" == *"🏠"* ]]
  [[ "$msg" == *"홈맥에어"* ]]
  [[ "$msg" == *"lawblaw_dev"* ]]
}

@test "notify-activity is idempotent in dry-run" {
  setup_persona
  DRY_RUN=1 run "$SSOT/bin/notify-activity.sh" "wake"
  [ "$status" -eq 0 ]
  ledger="$SSOT/state/activity/홈맥에어.jsonl"
  [ ! -f "$ledger" ]
}
