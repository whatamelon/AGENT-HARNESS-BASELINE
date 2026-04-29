load test_helper

@test "summarize-session formats minimal info" {
  run "$SSOT/bin/summarize-session.sh" "/tmp/myproject" 15 0 5
  [ "$status" -eq 0 ]
  [[ "$output" == *"myproject"* ]]
  [[ "$output" == *"15분"* ]]
  [[ "$output" == *"5 files"* ]]
}

@test "summarize-session shows commit count" {
  run "$SSOT/bin/summarize-session.sh" "/tmp/myproject" 22 3 12
  [[ "$output" == *"3 commits"* ]]
}

@test "summarize-session reads last commit message from cwd if it's a git repo" {
  tmp_repo=$(mktemp -d)
  cd "$tmp_repo"
  git init -q
  git config user.email "t@t" && git config user.name "t"
  echo "x" > a.txt
  git add a.txt
  git commit -q -m "fix(auth): SSO 토큰 검증"

  cd "$SSOT"
  run "$SSOT/bin/summarize-session.sh" "$tmp_repo" 22 1 1
  [[ "$output" == *"SSO 토큰 검증"* ]]
  rm -rf "$tmp_repo"
}

@test "summarize-session handles non-git cwd gracefully" {
  tmp_dir=$(mktemp -d)
  run "$SSOT/bin/summarize-session.sh" "$tmp_dir" 5 0 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"5분"* ]]
  rm -rf "$tmp_dir"
}

@test "summarize-session uses basename of cwd" {
  run "$SSOT/bin/summarize-session.sh" "/Users/x/dev/lawblaw_dev" 10 1 3
  [[ "$output" == *"lawblaw_dev"* ]]
  [[ "$output" != *"/Users/x/dev/lawblaw_dev"* ]]
}
