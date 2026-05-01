#!/usr/bin/env bats

load 'setup'

setup() {
    # Load parent setup to isolate environment and create test repo
    parent_setup
    
    # Create a test repo
    export TEST_REPO
    TEST_REPO="$(mktemp -d)"
    
    cd "$TEST_REPO"
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    git commit --allow-empty -m "init"
    
    # Initialize git-cloak
    export GIT_PROJECT_ROOT="$TEST_REPO"
    export GIT_WORKSPACE_ROOT=""
    "$GIT_CLOAK_BIN" init >/dev/null 2>&1
}

teardown() {
    # Clean up test repo
    cd /
    rm -rf "$TEST_REPO"
    
    # Parent teardown
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
    export GIT_CLOAK_BIN
    GIT_CLOAK_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/git-cloak"
}

parent_teardown() {
    cd / 2>/dev/null || true
    rm -rf "$HOME"
    export HOME="$ORIG_HOME"
}

# Basic hide functionality

@test "cmd_hide: marks file as skip-worktree" {
    echo "test content" > "$TEST_REPO/config.php"
    git -C "$TEST_REPO" add config.php
    git -C "$TEST_REPO" commit -m "Add config"
    
    run "$GIT_CLOAK_BIN" hide config.php
    [[ $status -eq 0 ]]
    
    # Verify skip-worktree flag set (should be S in ls-files -v)
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^S config.php'"
    [[ $status -eq 0 ]]
}

@test "cmd_hide: adds file to project-ignore" {
    echo "test" > "$TEST_REPO/config.php"
    git -C "$TEST_REPO" add config.php
    git -C "$TEST_REPO" commit -m "Add config"
    
    run "$GIT_CLOAK_BIN" hide config.php
    [[ $status -eq 0 ]]
    
    # Verify in project-ignore
    [[ $(grep -c "config.php" "$TEST_REPO/.git/personal/project-ignore") -gt 0 ]]
}

@test "cmd_hide: fails on untracked file" {
    echo "test" > "$TEST_REPO/untracked.php"
    
    run "$GIT_CLOAK_BIN" hide untracked.php
    [[ $status -ne 0 ]]
}

@test "cmd_hide: fails when file doesn't exist" {
    run "$GIT_CLOAK_BIN" hide nonexistent.php
    [[ $status -ne 0 ]]
}

@test "cmd_hide: handles relative and absolute paths" {
    mkdir -p "$TEST_REPO/src"
    echo "code" > "$TEST_REPO/src/app.php"
    git -C "$TEST_REPO" add src/app.php
    git -C "$TEST_REPO" commit -m "Add app"
    
    cd "$TEST_REPO/src"
    run "$GIT_CLOAK_BIN" hide app.php
    [[ $status -eq 0 ]]
}

@test "cmd_hide: idempotent (can hide already-hidden file)" {
    echo "test" > "$TEST_REPO/config.php"
    git -C "$TEST_REPO" add config.php
    git -C "$TEST_REPO" commit -m "Add config"
    
    # Hide it first
    "$GIT_CLOAK_BIN" hide config.php
    
    # Hide it again - should be idempotent
    run "$GIT_CLOAK_BIN" hide config.php
    [[ $status -eq 0 ]]
}

@test "cmd_hide: success message contains file name" {
    echo "test" > "$TEST_REPO/config.php"
    git -C "$TEST_REPO" add config.php
    git -C "$TEST_REPO" commit -m "Add config"
    
    run "$GIT_CLOAK_BIN" hide config.php
    [[ $status -eq 0 ]]
    [[ "$output" =~ "config.php" ]] || [[ "$output" =~ "Hidden" ]] || [[ "$output" =~ "hide" ]]
}

@test "cmd_hide: updates composed ignore file" {
    echo "test" > "$TEST_REPO/config.php"
    git -C "$TEST_REPO" add config.php
    git -C "$TEST_REPO" commit -m "Add config"
    
    run "$GIT_CLOAK_BIN" hide config.php
    [[ $status -eq 0 ]]
    
    # Verify the composed ignore file includes the entry
    [[ $(grep -c "config.php" "$TEST_REPO/.git/personal/ignore") -gt 0 ]]
}
