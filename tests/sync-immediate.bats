# tests/sync-immediate.bats
load test_helper

setup_git_repo() {
  cd "$SSOT"
  git init -q
  git config user.email "test@test"
  git config user.name "test"
  git commit --allow-empty -m "init" -q
}

@test "sync.sh --immediate flag is recognized" {
  setup_git_repo
  run "$SSOT/bin/sync.sh" --immediate
  [ "$status" -eq 0 ]
}

@test "sync.sh --immediate skips pull (no remote needed)" {
  setup_git_repo
  echo "test" > "$SSOT/test.txt"
  run "$SSOT/bin/sync.sh" --immediate
  [ "$status" -eq 0 ]
  cd "$SSOT"
  status_count=$(git status --porcelain | wc -l | tr -d ' ')
  [ "$status_count" = "0" ]
}

@test "sync.sh (no flag) keeps original pull behavior" {
  setup_git_repo
  run "$SSOT/bin/sync.sh"
  [ "$status" -eq 0 ]
}
