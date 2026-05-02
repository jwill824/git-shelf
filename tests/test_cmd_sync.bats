#!/usr/bin/env bats

load 'setup'

setup() {
    parent_setup
    
    # Create a test repo
    export TEST_REPO
    TEST_REPO="$(mktemp -d)"
    
    cd "$TEST_REPO"
    git init >/dev/null
    git config user.email "test@example.com"
    git config user.name "Test User"
    git commit --allow-empty -m "init" >/dev/null
    
    # Initialize git-cloak
    export GIT_PROJECT_ROOT="$TEST_REPO"
    export GIT_WORKSPACE_ROOT=""
    "$GIT_CLOAK_BIN" init >/dev/null 2>&1
}

teardown() {
    cd /
    rm -rf "$TEST_REPO"
    parent_teardown
}

parent_setup() {
    export ORIG_HOME="$HOME"
    export HOME
    HOME="$(mktemp -d)"
    export XDG_CONFIG_HOME="$HOME/.config"
    
    git config --global user.name "Test User"
    git config --global user.email "test@example.com"
    git config --global init.defaultBranch main
    
    export GIT_CLOAK_BIN
    GIT_CLOAK_BIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/git-cloak"
}

parent_teardown() {
    cd / 2>/dev/null || true
    rm -rf "$HOME"
    export HOME="$ORIG_HOME"
}

# Tests

@test "cmd_sync: succeeds when no files are hidden" {
    run "$GIT_CLOAK_BIN" sync
    [[ $status -eq 0 ]]
}

@test "cmd_sync: fails outside a git repository" {
    local non_git_dir=$(mktemp -d)
    cd "$non_git_dir"
    run "$GIT_CLOAK_BIN" sync
    rmdir "$non_git_dir" 2>/dev/null || true
    [[ $status -ne 0 ]]
}

@test "cmd_sync: re-applies skip-worktree" {
    # Create and hide file
    echo "test" > "$TEST_REPO/file.txt"
    cd "$TEST_REPO"
    git add file.txt
    git commit -m "Add file" >/dev/null
    
    "$GIT_CLOAK_BIN" hide file.txt >/dev/null
    
    # Check skip-worktree is set
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^S file.txt'"
    [[ $status -eq 0 ]]
    
    # Clear it
    git -C "$TEST_REPO" update-index --no-skip-worktree file.txt
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^S file.txt'"
    [[ $status -ne 0 ]]
    
    # Sync should restore it
    run "$GIT_CLOAK_BIN" sync
    [[ $status -eq 0 ]]
    
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^S file.txt'"
    [[ $status -eq 0 ]]
}

@test "cmd_sync: handles multiple files" {
    cd "$TEST_REPO"
    echo "a" > a.txt
    echo "b" > b.txt
    git add a.txt b.txt
    git commit -m "Add files" >/dev/null
    
    "$GIT_CLOAK_BIN" hide a.txt >/dev/null
    "$GIT_CLOAK_BIN" hide b.txt >/dev/null
    
    git -C "$TEST_REPO" update-index --no-skip-worktree a.txt b.txt
    
    run "$GIT_CLOAK_BIN" sync
    [[ $status -eq 0 ]]
    
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^S' | wc -l | tr -d ' '"
    [[ "$output" == "2" ]]
}

@test "cmd_sync: displays success message" {
    cd "$TEST_REPO"
    echo "x" > x.txt
    git add x.txt
    git commit -m "Add" >/dev/null
    
    "$GIT_CLOAK_BIN" hide x.txt >/dev/null
    git -C "$TEST_REPO" update-index --no-skip-worktree x.txt
    
    run "$GIT_CLOAK_BIN" sync
    [[ $status -eq 0 ]]
    [[ "$output" =~ "Re-synced" ]]
}

@test "cmd_sync: preserves composed ignore" {
    cd "$TEST_REPO"
    echo "y" > y.txt
    git add y.txt
    git commit -m "Add" >/dev/null
    
    "$GIT_CLOAK_BIN" hide y.txt >/dev/null
    
    run "$GIT_CLOAK_BIN" sync
    [[ $status -eq 0 ]]
    
    [[ $(grep -c "y.txt" "$TEST_REPO/.git/personal/ignore") -gt 0 ]]
}

@test "cmd_sync: is idempotent" {
    cd "$TEST_REPO"
    echo "z" > z.txt
    git add z.txt
    git commit -m "Add" >/dev/null
    
    "$GIT_CLOAK_BIN" hide z.txt >/dev/null
    git -C "$TEST_REPO" update-index --no-skip-worktree z.txt
    
    "$GIT_CLOAK_BIN" sync >/dev/null
    run "$GIT_CLOAK_BIN" sync
    [[ $status -eq 0 ]]
    
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^S z.txt'"
    [[ $status -eq 0 ]]
}

@test "cmd_sync: skips untracked files" {
    cd "$TEST_REPO"
    echo "tracked" > tracked.txt
    git add tracked.txt
    git commit -m "Add" >/dev/null
    
    "$GIT_CLOAK_BIN" hide tracked.txt >/dev/null
    echo "untracked.txt" >> "$TEST_REPO/.git/personal/project-ignore"
    
    run "$GIT_CLOAK_BIN" sync
    [[ $status -eq 0 ]]
    
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^S' | wc -l | tr -d ' '"
    [[ "$output" == "1" ]]
}

@test "cmd_sync: reports updated count" {
    cd "$TEST_REPO"
    echo "file1" > file1.txt
    echo "file2" > file2.txt
    git add file1.txt file2.txt
    git commit -m "Add" >/dev/null
    
    "$GIT_CLOAK_BIN" hide file1.txt >/dev/null
    "$GIT_CLOAK_BIN" hide file2.txt >/dev/null
    
    git -C "$TEST_REPO" update-index --no-skip-worktree file1.txt file2.txt
    
    run "$GIT_CLOAK_BIN" sync
    [[ $status -eq 0 ]]
    [[ "$output" =~ "Updated" ]]
}
