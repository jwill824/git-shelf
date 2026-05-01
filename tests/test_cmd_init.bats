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
    
    # Export GIT_PROJECT_ROOT for the command
    export GIT_PROJECT_ROOT="$TEST_REPO"
    export GIT_WORKSPACE_ROOT=""
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

# Basic initialization tests

@test "cmd_init: initializes .git/personal directory" {
    run "$GIT_CLOAK_BIN" init
    [[ $status -eq 0 ]]
    [[ -d "$TEST_REPO/.git/personal" ]]
}

@test "cmd_init: creates project-ignore file" {
    run "$GIT_CLOAK_BIN" init
    [[ $status -eq 0 ]]
    [[ -f "$TEST_REPO/.git/personal/project-ignore" ]]
}

@test "cmd_init: creates composed ignore file" {
    run "$GIT_CLOAK_BIN" init
    [[ $status -eq 0 ]]
    [[ -f "$TEST_REPO/.git/personal/ignore" ]]
}

@test "cmd_init: configures git core.excludesFile" {
    run "$GIT_CLOAK_BIN" init
    [[ $status -eq 0 ]]
    
    run bash -c "git -C '$TEST_REPO' config core.excludesFile"
    [[ "$output" == ".git/personal/ignore" ]]
}

# Idempotency tests

@test "cmd_init: is idempotent (can run multiple times)" {
    run "$GIT_CLOAK_BIN" init
    [[ $status -eq 0 ]]
    
    # Run again
    run "$GIT_CLOAK_BIN" init
    [[ $status -eq 0 ]]
    
    # Should still be initialized
    [[ -d "$TEST_REPO/.git/personal" ]]
    [[ -f "$TEST_REPO/.git/personal/project-ignore" ]]
    [[ -f "$TEST_REPO/.git/personal/ignore" ]]
}

@test "cmd_init: preserves existing project-ignore on re-init" {
    # First init
    "$GIT_CLOAK_BIN" init
    
    # Add custom content to project-ignore
    echo "*.custom" >> "$TEST_REPO/.git/personal/project-ignore"
    initial_content=$(cat "$TEST_REPO/.git/personal/project-ignore")
    
    # Re-init should not delete project-ignore content
    "$GIT_CLOAK_BIN" init
    
    final_content=$(cat "$TEST_REPO/.git/personal/project-ignore")
    [[ "$final_content" == "$initial_content" ]]
    [[ $(grep -c "*.custom" "$TEST_REPO/.git/personal/project-ignore") -gt 0 ]]
}

# Flag tests

@test "cmd_init: works with --workspace flag" {
    run "$GIT_CLOAK_BIN" init --workspace
    [[ $status -eq 0 ]]
    [[ -d "$TEST_REPO/.git/personal" ]]
}

# Error cases

@test "cmd_init: fails outside a git repository" {
    # Create a non-git directory and ensure it stays non-git
    _TMP_DIR=$(mktemp -d)
    
    # Save current dir and switch to temp dir without git repo
    _ORIG_DIR="$PWD"
    cd "$_TMP_DIR"
    
    # Unset GIT_PROJECT_ROOT to force resolution
    unset GIT_PROJECT_ROOT
    
    run "$GIT_CLOAK_BIN" init
    [[ $status -ne 0 ]]
    
    cd "$_ORIG_DIR"
    rm -rf "$_TMP_DIR"
}

@test "cmd_init: displays success message" {
    run "$GIT_CLOAK_BIN" init
    [[ $status -eq 0 ]]
    [[ "$output" =~ "git cloak" ]] || [[ "$output" =~ "initialized" ]] || [[ "$output" =~ "init" ]]
}

@test "cmd_init: composes ignore file with project scope" {
    # Add content to project-ignore
    mkdir -p "$TEST_REPO/.git/personal"
    echo "*.log" > "$TEST_REPO/.git/personal/project-ignore"
    
    # Run init
    "$GIT_CLOAK_BIN" init
    
    # Composed ignore should include project content
    [[ $(grep -c "*.log" "$TEST_REPO/.git/personal/ignore") -gt 0 ]]
}

@test "cmd_init: verifies in a git repository" {
    # This should succeed (we're in TEST_REPO which is a git repo)
    run "$GIT_CLOAK_BIN" init
    [[ $status -eq 0 ]]
    
    # Verify git config was set in the actual git repo
    run bash -c "cd '$TEST_REPO' && git config core.excludesFile"
    [[ "$output" == ".git/personal/ignore" ]]
}

@test "cmd_init: respects pre-set GIT_PROJECT_ROOT environment variable" {
    # Verify that if GIT_PROJECT_ROOT is already set, we use it
    export GIT_PROJECT_ROOT="$TEST_REPO"
    
    run "$GIT_CLOAK_BIN" init
    [[ $status -eq 0 ]]
    
    # Should have initialized the correct directory
    [[ -d "$TEST_REPO/.git/personal" ]]
    [[ -f "$TEST_REPO/.git/personal/ignore" ]]
}
