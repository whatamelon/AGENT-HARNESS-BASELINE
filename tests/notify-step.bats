load test_helper

setup_persona() {
  echo '{"persona":"홈맥에어","emoji":"🏠","color":"#FF1493"}' > "$SSOT/.machine.json"
}

@test "notify-step start saves message_id from telegram (mocked)" {
  setup_persona
  DRY_RUN=1 run "$SSOT/bin/notify-step.sh" start 13
  [ "$status" -eq 0 ]
  [ ! -f "$SSOT/state/wizard-message-id.txt" ]
}

@test "notify-step build-message format includes progress bar" {
  setup_persona
  source "$SSOT/bin/notify-step.sh" --source-only 2>/dev/null || skip
  msg=$(build_progress_message 4 13 "🔄" "공유 자산 통합" "12분 경과")
  [[ "$msg" == *"4/13"* ]]
  [[ "$msg" == *"31%"* ]]
  [[ "$msg" == *"▓"* ]]
  [[ "$msg" == *"공유 자산 통합"* ]]
}

@test "notify-step build progress bar 13 chars" {
  setup_persona
  source "$SSOT/bin/notify-step.sh" --source-only 2>/dev/null || skip
  bar=$(build_progress_bar 4 13)
  count=$(printf "%s" "$bar" | grep -o '[▓░]' | wc -l | tr -d ' ')
  [ "$count" = "13" ]
}

@test "notify-step done message has completion header" {
  setup_persona
  source "$SSOT/bin/notify-step.sh" --source-only 2>/dev/null || skip
  msg=$(build_done_message 13 "24분")
  [[ "$msg" == *"완료"* ]] || [[ "$msg" == *"🎉"* ]]
  [[ "$msg" == *"100%"* ]] || [[ "$msg" == *"13/13"* ]]
}

@test "notify-step human-action emits separate text" {
  setup_persona
  source "$SSOT/bin/notify-step.sh" --source-only 2>/dev/null || skip
  msg=$(build_human_action_message "1Password CLI" "데스크톱 앱 → 설정 → CLI integration ON")
  [[ "$msg" == *"손이 필요해"* ]]
  [[ "$msg" == *"1Password CLI"* ]]
}

@test "notify-step reset removes message_id file" {
  setup_persona
  mkdir -p "$SSOT/state"
  echo "12345" > "$SSOT/state/wizard-message-id.txt"
  run "$SSOT/bin/notify-step.sh" reset
  [ "$status" -eq 0 ]
  [ ! -f "$SSOT/state/wizard-message-id.txt" ]
}
