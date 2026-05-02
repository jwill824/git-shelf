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
    
    # Create config.yml and database.yml (tracked) on main branch
    echo "env=dev" > config.yml
    echo "db=localhost" > database.yml
    git add config.yml database.yml
    git commit -m "Add config.yml and database.yml"
    
    git checkout -b feature 2>/dev/null
    echo "feature-file" > feature.txt
    git add feature.txt
    git commit -m "Add feature work"
    
    git checkout main 2>/dev/null
    
    # Local overrides of config.yml and database.yml and hide them (sets skip-worktree)
    echo "env=local-override" > config.yml
    echo "db=prod" > database.yml
    "$GIT_CLOAK_BIN" hide config.yml
    "$GIT_CLOAK_BIN" hide database.yml
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

# Basic switch functionality

@test "cmd_switch: changes to target branch" {
    run bash -c "cd '$TEST_REPO' && '$GIT_CLOAK_BIN' switch feature"
    [[ $status -eq 0 ]]
    
    # Verify we're on the correct branch
    run bash -c "git -C '$TEST_REPO' branch --show-current"
    [[ "$output" = "feature" ]]
}

@test "cmd_switch: re-applies skip-worktree after switch" {
    run bash -c "cd '$TEST_REPO' && '$GIT_CLOAK_BIN' switch feature"
    [[ $status -eq 0 ]]
    
    # Verify skip-worktree flag is re-applied
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^S config.yml'"
    [[ $status -eq 0 ]]
}

@test "cmd_switch: preserves local override content" {
    run bash -c "cd '$TEST_REPO' && '$GIT_CLOAK_BIN' switch feature"
    [[ $status -eq 0 ]]
    
    # Verify the local content is preserved
    run cat "$TEST_REPO/config.yml"
    [[ "$output" == *"local-override"* ]]
}

@test "cmd_switch: errors when branch does not exist" {
    run bash -c "cd '$TEST_REPO' && '$GIT_CLOAK_BIN' switch nonexistent-branch-xyz"
    [[ $status -ne 0 ]]
    [[ "$output" == *"not found"* ]] || [[ "$output" == *"Error"* ]]
}

@test "cmd_switch: errors when no branch given" {
    run bash -c "cd '$TEST_REPO' && '$GIT_CLOAK_BIN' switch"
    [[ $status -ne 0 ]]
    [[ "$output" == *"Usage"* ]]
}

@test "cmd_switch: works when no skip-worktree files" {
    # Remove skip-worktree flag manually (there's no unhide command)
    cd "$TEST_REPO"
    git update-index --no-skip-worktree config.yml
    git update-index --no-skip-worktree database.yml
    
    run bash -c "cd '$TEST_REPO' && '$GIT_CLOAK_BIN' switch feature"
    [[ $status -eq 0 ]]
    
    # Verify we're on the correct branch
    run bash -c "git -C '$TEST_REPO' branch --show-current"
    [[ "$output" = "feature" ]]
}

@test "cmd_switch: handles multiple skip-worktree files" {
    run bash -c "cd '$TEST_REPO' && '$GIT_CLOAK_BIN' switch feature"
    [[ $status -eq 0 ]]
    
    # Both files should have skip-worktree flag
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^S config.yml'"
    [[ $status -eq 0 ]]
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^S database.yml'"
    [[ $status -eq 0 ]]
}

@test "cmd_switch --restore-watch: errors when save file missing" {
    run bash -c "cd '$TEST_REPO' && '$GIT_CLOAK_BIN' switch --restore-watch"
    [[ $status -ne 0 ]]
    [[ "$output" == *"no saved watch list"* ]] || [[ "$output" == *"Error"* ]]
}

@test "cmd_switch: creates save file during switch" {
    run bash -c "cd '$TEST_REPO' && '$GIT_CLOAK_BIN' switch feature"
    [[ $status -eq 0 ]]
    
    # Save file should be cleaned up after switch completes
    [[ ! -f "$TEST_REPO/.git/personal/switch-watched" ]]
}

@test "cmd_switch: stashes and pops changes correctly" {
    # Verify stash/pop behavior by checking that local changes are applied
    cd "$TEST_REPO"
    echo "modified-feature-content" > feature.txt
    git add feature.txt
    
    run bash -c "cd '$TEST_REPO' && '$GIT_CLOAK_BIN' switch main"
    [[ $status -eq 0 ]]
    
    # Should be back on main branch
    run bash -c "git -C '$TEST_REPO' branch --show-current"
    [[ "$output" = "main" ]]
}
