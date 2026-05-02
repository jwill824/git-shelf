#!/usr/bin/env bats

load 'setup'

setup() {
  load 'setup'
  setup
  cd "$TEST_REPO"
  "$GIT_CLOAK" init
}

@test "monitor add: adds file to watch-list" {
  run "$GIT_CLOAK" monitor add config.yml
  [ "$status" -eq 0 ]
  run grep "config.yml" "$TEST_REPO/.git/personal/watch-list"
  [ "$status" -eq 0 ]
}

@test "monitor add: is idempotent (no duplicate entries)" {
  "$GIT_CLOAK" monitor add config.yml
  run "$GIT_CLOAK" monitor add config.yml
  [ "$status" -eq 0 ]
  run grep -c "config.yml" "$TEST_REPO/.git/personal/watch-list"
  [ "$output" -eq 1 ]
}

@test "monitor remove: removes file from watch-list" {
  "$GIT_CLOAK" monitor add config.yml
  run "$GIT_CLOAK" monitor remove config.yml
  [ "$status" -eq 0 ]
  run grep "config.yml" "$TEST_REPO/.git/personal/watch-list"
  [ "$status" -ne 0 ]
}

@test "monitor remove: no-ops when file not in list" {
  run "$GIT_CLOAK" monitor remove nonexistent.yml
  [ "$status" -eq 0 ]
  [[ "$output" == *"Not in watch list"* ]]
}

@test "monitor list: shows monitored files" {
  "$GIT_CLOAK" monitor add config.yml
  "$GIT_CLOAK" monitor add secrets.yml
  run "$GIT_CLOAK" monitor list
  [ "$status" -eq 0 ]
  [[ "$output" == *"config.yml"* ]]
  [[ "$output" == *"secrets.yml"* ]]
}

@test "monitor list: reports empty when list is empty" {
  run "$GIT_CLOAK" monitor list
  [ "$status" -eq 0 ]
  [[ "$output" == *"empty"* ]]
}

@test "monitor: errors with no subcommand" {
  run "$GIT_CLOAK" monitor
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "monitor add: errors with no args" {
  run "$GIT_CLOAK" monitor add
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}
