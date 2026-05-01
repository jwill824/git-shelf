#!/usr/bin/env bats

load 'setup'

@test "test infrastructure: git is available" {
  run git --version
  [ "$status" -eq 0 ]
}

@test "test infrastructure: HOME is isolated" {
  [ "$HOME" != "$ORIG_HOME" ]
}

@test "test infrastructure: TEST_REPO is a git repo" {
  run git -C "$TEST_REPO" rev-parse --show-toplevel
  [ "$status" -eq 0 ]
}

@test "test infrastructure: TEST_REPO has origin/main" {
  run git -C "$TEST_REPO" rev-parse --verify origin/main
  [ "$status" -eq 0 ]
}
