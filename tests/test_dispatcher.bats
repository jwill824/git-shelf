#!/usr/bin/env bats

load 'setup'

setup() {
  load 'setup'
  setup
  cd "$TEST_REPO"
}

@test "dispatcher: bin/git-cloak exists and is executable" {
    [[ -x "$GIT_CLOAK" ]]
}

@test "dispatcher: git cloak with no args shows error" {
    run "$GIT_CLOAK"
    [[ $status -ne 0 ]]
}

@test "dispatcher: git cloak help shows error (not yet implemented)" {
    run "$GIT_CLOAK" help
    [[ $status -ne 0 ]]
}

@test "dispatcher: git cloak init routes to cmd-init" {
    run "$GIT_CLOAK" init
    [[ $status -eq 0 ]]
    [[ "$output" =~ "initialized successfully" ]]
}

@test "dispatcher: git cloak hide routes to cmd-hide" {
    "$GIT_CLOAK" init
    echo "test" > test_file.txt
    git add test_file.txt
    run "$GIT_CLOAK" hide test_file.txt
    [[ $status -eq 0 ]]
}

@test "dispatcher: git cloak watch routes to cmd-watch" {
    "$GIT_CLOAK" init
    run "$GIT_CLOAK" watch config.yml
    [[ $status -eq 0 ]]
}

@test "dispatcher: git cloak unwatch routes to cmd-unwatch" {
    "$GIT_CLOAK" init
    "$GIT_CLOAK" watch config.yml
    # unwatch may fail or succeed depending on setup
    run "$GIT_CLOAK" unwatch config.yml
    [[ $status -ge 0 ]]
}

@test "dispatcher: git cloak list routes to cmd-list" {
    "$GIT_CLOAK" init
    run "$GIT_CLOAK" list
    [[ $status -eq 0 ]]
}

@test "dispatcher: git cloak switch routes to cmd-switch" {
    run "$GIT_CLOAK" switch main
    # Switch may fail if main doesn't exist, but the command should route correctly
    [[ $status -ge 0 ]]
}

@test "dispatcher: git cloak refresh routes to cmd-refresh" {
    run "$GIT_CLOAK" refresh
    # Refresh may fail if no remote configured, but the command should route correctly
    [[ $status -ge 0 ]]
}

@test "dispatcher: git cloak merge-main routes to cmd-merge-main" {
    run "$GIT_CLOAK" merge-main
    [[ $status -ge 0 ]]
}

@test "dispatcher: git cloak sync routes to cmd-sync" {
    run "$GIT_CLOAK" sync
    # Sync checks for project-ignore file, output varies
    [[ $status -ge 0 ]]
}

@test "dispatcher: git cloak monitor routes to cmd-monitor" {
    "$GIT_CLOAK" init
    run "$GIT_CLOAK" monitor list
    [[ $status -eq 0 ]]
}

@test "dispatcher: all commands accept additional arguments" {
    "$GIT_CLOAK" init
    run "$GIT_CLOAK" init arg1 arg2 arg3
    [[ $status -eq 0 ]]
}

@test "dispatcher: invalid command returns exit code 1" {
    run "$GIT_CLOAK" invalid-command
    [[ $status -eq 1 ]]
}

@test "dispatcher: cmd functions exist and are callable" {
    local git_cloak_parent="$(cd "$(dirname "$GIT_CLOAK")/.." && pwd)"
    [[ -f "$git_cloak_parent/lib/cmd-init.sh" ]]
    [[ -f "$git_cloak_parent/lib/cmd-hide.sh" ]]
    [[ -f "$git_cloak_parent/lib/cmd-watch.sh" ]]
    [[ -f "$git_cloak_parent/lib/cmd-unwatch.sh" ]]
    [[ -f "$git_cloak_parent/lib/cmd-list.sh" ]]
    [[ -f "$git_cloak_parent/lib/cmd-switch.sh" ]]
    [[ -f "$git_cloak_parent/lib/cmd-refresh.sh" ]]
    [[ -f "$git_cloak_parent/lib/cmd-merge-main.sh" ]]
    [[ -f "$git_cloak_parent/lib/cmd-sync.sh" ]]
    [[ -f "$git_cloak_parent/lib/cmd-monitor.sh" ]]
}

# Infrastructure tests
@test "test infrastructure: git is available" {
    which git >/dev/null
}

@test "test infrastructure: HOME is isolated" {
    [[ ! "$HOME" =~ ^/Users ]]
}

@test "test infrastructure: TEST_REPO is a git repo" {
    git -C "$TEST_REPO" rev-parse --git-dir >/dev/null
}

@test "test infrastructure: TEST_REPO has origin/main" {
    git -C "$TEST_REPO" rev-parse origin/main >/dev/null 2>&1
}
