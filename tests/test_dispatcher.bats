#!/usr/bin/env bats

load 'setup'

setup() {
    parent_setup
}

teardown() {
    parent_teardown
}

parent_setup() {
    # Isolate from real HOME
    export ORIG_HOME="$HOME"
    export HOME
    HOME="$(mktemp -d)"
    export XDG_CONFIG_HOME="$HOME/.config"
    
    # Minimal git identity
    git config --global user.name "Test User"
    git config --global user.email "test@example.com"
    git config --global init.defaultBranch main
    
    # Locate the git-cloak binary relative to tests/
    export GIT_CLOAK
    GIT_CLOAK="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/git-cloak"
}

parent_teardown() {
    cd / 2>/dev/null || true
    rm -rf "$HOME"
    export HOME="$ORIG_HOME"
}

# Test that all commands can be dispatched

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
    [[ "$output" =~ "Unknown command" ]]
}

@test "dispatcher: git cloak init routes to cmd-init" {
    run bash -c "cd /tmp && $GIT_CLOAK init"
    [[ $status -eq 0 ]]
    [[ "$output" =~ "initialized" ]]
}

@test "dispatcher: git cloak hide routes to cmd-hide" {
    run "$GIT_CLOAK" hide
    [[ $status -eq 0 ]]
}

@test "dispatcher: git cloak watch routes to cmd-watch" {
    run "$GIT_CLOAK" watch
    [[ $status -eq 0 ]]
}

@test "dispatcher: git cloak unwatch routes to cmd-unwatch" {
    run "$GIT_CLOAK" unwatch
    [[ $status -eq 0 ]]
}

@test "dispatcher: git cloak list routes to cmd-list" {
    run bash -c "cd /tmp && $GIT_CLOAK list"
    [[ $status -eq 0 ]]
}

@test "dispatcher: git cloak switch routes to cmd-switch" {
    run "$GIT_CLOAK" switch
    [[ "$output" =~ "TODO: Implement git cloak switch" ]]
}

@test "dispatcher: git cloak refresh routes to cmd-refresh" {
    run "$GIT_CLOAK" refresh
    [[ $status -eq 0 ]]
}

@test "dispatcher: git cloak merge-main routes to cmd-merge-main" {
    run "$GIT_CLOAK" merge-main
    [[ $status -eq 0 ]]
}

@test "dispatcher: git cloak monitor routes to cmd-monitor" {
    run "$GIT_CLOAK" monitor
    [[ $status -ne 0 ]]
    [[ "$output" =~ "Usage" ]]
}

@test "dispatcher: git cloak sync routes to cmd-sync" {
    run "$GIT_CLOAK" sync
    [[ "$output" =~ "TODO: Implement git cloak sync" ]]
}

@test "dispatcher: all commands accept additional arguments" {
    run "$GIT_CLOAK" init --workspace /tmp/test arg1 arg2
    [[ $status -eq 0 ]]
}

@test "dispatcher: invalid command returns exit code 1" {
    run "$GIT_CLOAK" nonexistent-command
    [[ $status -eq 1 ]]
}

@test "dispatcher: cmd functions exist and are callable" {
    run bash -c "source $GIT_CLOAK/../lib/common.sh && source $GIT_CLOAK/../lib/cmd-init.sh && type cmd_init | grep function"
    [[ $status -eq 0 ]]
}
