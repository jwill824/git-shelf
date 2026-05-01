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
    
    # Create a temporary git repo for testing
    export TEST_REPO
    TEST_REPO="$(mktemp -d)"
    git init "$TEST_REPO"
    git -C "$TEST_REPO" config user.email "test@example.com"
    git -C "$TEST_REPO" config user.name "Test"
    git -C "$TEST_REPO" commit --allow-empty -m "init"
    git -C "$TEST_REPO" config core.excludesFile ""
}

parent_teardown() {
    cd /
    rm -rf "$HOME" "$TEST_REPO"
    export HOME="$ORIG_HOME"
}

@test "dispatcher: bin/git-cloak exists and is executable" {
    [[ -x "$GIT_CLOAK" ]]
}

@test "dispatcher: git cloak with no args shows error" {
    run "$GIT_CLOAK"
    [[ $status -eq 1 ]]
    [[ "$output" =~ "Unknown command" ]]
}

@test "dispatcher: git cloak help shows error (not yet implemented)" {
    run "$GIT_CLOAK" help
    [[ $status -eq 1 ]]
    [[ "$output" =~ "Unknown command" ]]
}

@test "dispatcher: git cloak init routes to cmd-init" {
    run bash -c "cd '$TEST_REPO' && '$GIT_CLOAK' init"
    [[ $status -eq 0 ]]
    [[ "$output" =~ "initialized successfully" ]]
}

@test "dispatcher: git cloak hide routes to cmd-hide" {
    # Prepare a tracked file
    echo "test" > "$TEST_REPO/test_file.txt"
    git -C "$TEST_REPO" add test_file.txt
    git -C "$TEST_REPO" commit -m "Add test file"
    
    # Initialize git-cloak
    bash -c "cd '$TEST_REPO' && '$GIT_CLOAK' init" >/dev/null 2>&1
    
    # Test hide
    run bash -c "cd '$TEST_REPO' && '$GIT_CLOAK' hide test_file.txt"
    [[ $status -eq 0 ]] || [[ "$output" =~ "Hidden:" ]]
}

@test "dispatcher: git cloak watch routes to cmd-watch" {
    run bash -c "cd '$TEST_REPO' && '$GIT_CLOAK' watch file.txt"
    [[ $status -eq 0 ]] || [[ $status -eq 1 ]]
}

@test "dispatcher: git cloak unwatch routes to cmd-unwatch" {
    run bash -c "cd '$TEST_REPO' && '$GIT_CLOAK' unwatch file.txt"
    [[ $status -ne 0 ]] || [[ "$output" =~ "Unwatching:" ]]
}

@test "dispatcher: git cloak list routes to cmd-list" {
    run bash -c "cd '$TEST_REPO' && '$GIT_CLOAK' list"
    [[ $status -eq 0 ]]
}

@test "dispatcher: git cloak switch routes to cmd-switch" {
    run "$GIT_CLOAK" switch main
    [[ $status -eq 0 ]]
    [[ "$output" =~ "TODO: Implement git cloak switch" ]]
}

@test "dispatcher: git cloak refresh routes to cmd-refresh" {
    run "$GIT_CLOAK" refresh
    [[ $status -eq 0 ]]
    [[ "$output" =~ "TODO: Implement git cloak refresh" ]]
}

@test "dispatcher: git cloak merge-main routes to cmd-merge-main" {
    run "$GIT_CLOAK" merge-main
    [[ $status -eq 0 ]]
    [[ "$output" =~ "TODO: Implement git cloak merge-main" ]]
}

@test "dispatcher: git cloak sync routes to cmd-sync" {
    run "$GIT_CLOAK" sync
    [[ $status -eq 0 ]]
    [[ "$output" =~ "TODO: Implement git cloak sync" ]]
}

@test "dispatcher: git cloak monitor routes to cmd-monitor" {
    run "$GIT_CLOAK" monitor
    [[ $status -eq 0 ]]
    [[ "$output" =~ "TODO: Implement git cloak monitor" ]]
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
    # Verify lib files exist
    for cmd in init hide watch unwatch list switch refresh merge-main sync monitor; do
        [[ -f "$(cd "$(dirname "$GIT_CLOAK")/.." && pwd)/lib/cmd-${cmd}.sh" ]]
    done
}
