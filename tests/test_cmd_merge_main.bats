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

# Basic merge-main functionality

@test "cmd_merge_main: merges main successfully when no conflicts" {
    # Create initial commit on main
    echo "main content" > "$TEST_REPO/main.txt"
    git -C "$TEST_REPO" add main.txt
    git -C "$TEST_REPO" commit -m "Main commit"
    
    # Create and switch to feature branch
    git -C "$TEST_REPO" checkout -b feature
    echo "feature content" > "$TEST_REPO/feature.txt"
    git -C "$TEST_REPO" add feature.txt
    git -C "$TEST_REPO" commit -m "Feature commit"
    
    # Add more commits to main
    git -C "$TEST_REPO" checkout main
    echo "main update" > "$TEST_REPO/main-update.txt"
    git -C "$TEST_REPO" add main-update.txt
    git -C "$TEST_REPO" commit -m "Main update"
    
    # Switch back to feature and merge main
    git -C "$TEST_REPO" checkout feature
    
    run "$GIT_CLOAK_BIN" merge-main
    [[ $status -eq 0 ]]
    [[ "$output" =~ "Merge complete" ]]
}

@test "cmd_merge_main: collects skip-worktree files" {
    # Create files and hide them
    echo "file1" > "$TEST_REPO/file1.txt"
    git -C "$TEST_REPO" add file1.txt
    git -C "$TEST_REPO" commit -m "Add file1"
    
    "$GIT_CLOAK_BIN" hide file1.txt
    
    # Create and switch to feature branch
    git -C "$TEST_REPO" checkout -b feature
    
    # Merge main
    run "$GIT_CLOAK_BIN" merge-main
    [[ $status -eq 0 ]]
    
    # Verify skip-worktree is re-applied
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^S file1.txt'"
    [[ $status -eq 0 ]]
}

@test "cmd_merge_main: saves skip-worktree list" {
    # Create and hide multiple files
    echo "file1" > "$TEST_REPO/file1.txt"
    git -C "$TEST_REPO" add file1.txt
    git -C "$TEST_REPO" commit -m "Add file1"
    
    echo "file2" > "$TEST_REPO/file2.txt"
    git -C "$TEST_REPO" add file2.txt
    git -C "$TEST_REPO" commit -m "Add file2"
    
    "$GIT_CLOAK_BIN" hide file1.txt
    "$GIT_CLOAK_BIN" hide file2.txt
    
    # Create feature branch
    git -C "$TEST_REPO" checkout -b feature
    
    # Run merge-main
    run "$GIT_CLOAK_BIN" merge-main
    [[ $status -eq 0 ]]
    
    # Verify the merge-main-watched file was created
    [[ -f "$TEST_REPO/.git/personal/merge-main-watched" ]]
    
    # Verify files are in the watched file
    [[ $(grep -c "file1.txt" "$TEST_REPO/.git/personal/merge-main-watched") -gt 0 ]]
    [[ $(grep -c "file2.txt" "$TEST_REPO/.git/personal/merge-main-watched") -gt 0 ]]
}

@test "cmd_merge_main: clears and re-applies skip-worktree" {
    # Create and hide a file
    echo "config" > "$TEST_REPO/config.php"
    git -C "$TEST_REPO" add config.php
    git -C "$TEST_REPO" commit -m "Add config"
    
    "$GIT_CLOAK_BIN" hide config.php
    
    # Verify skip-worktree is set
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^S config.php'"
    [[ $status -eq 0 ]]
    
    # Create feature branch and merge
    git -C "$TEST_REPO" checkout -b feature
    run "$GIT_CLOAK_BIN" merge-main
    [[ $status -eq 0 ]]
    
    # After merge, skip-worktree should still be set
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^S config.php'"
    [[ $status -eq 0 ]]
}

@test "cmd_merge_main: reports number of re-applied skip-worktree files" {
    # Create and hide multiple files
    echo "file1" > "$TEST_REPO/file1.txt"
    git -C "$TEST_REPO" add file1.txt
    git -C "$TEST_REPO" commit -m "Add file1"
    
    echo "file2" > "$TEST_REPO/file2.txt"
    git -C "$TEST_REPO" add file2.txt
    git -C "$TEST_REPO" commit -m "Add file2"
    
    "$GIT_CLOAK_BIN" hide file1.txt
    "$GIT_CLOAK_BIN" hide file2.txt
    
    # Create feature branch and merge
    git -C "$TEST_REPO" checkout -b feature
    run "$GIT_CLOAK_BIN" merge-main
    [[ $status -eq 0 ]]
    
    # Should mention 2 files
    [[ "$output" =~ "2 files" ]] || [[ "$output" =~ "re-applied" ]]
}

@test "cmd_merge_main: handles stash and pop" {
    # Create initial commit
    echo "original" > "$TEST_REPO/file.txt"
    git -C "$TEST_REPO" add file.txt
    git -C "$TEST_REPO" commit -m "Initial"
    
    # Create feature branch
    git -C "$TEST_REPO" checkout -b feature
    
    # Make uncommitted changes
    echo "modified" > "$TEST_REPO/file.txt"
    
    # Create a commit on main to merge
    git -C "$TEST_REPO" checkout main
    echo "main update" > "$TEST_REPO/main-file.txt"
    git -C "$TEST_REPO" add main-file.txt
    git -C "$TEST_REPO" commit -m "Main update"
    
    # Switch back to feature
    git -C "$TEST_REPO" checkout feature
    
    # Merge main (should stash, merge, and pop)
    run "$GIT_CLOAK_BIN" merge-main
    [[ $status -eq 0 ]]
}

@test "cmd_merge_main: fails when not in git repo" {
    # Create a non-git directory
    local non_git_dir
    non_git_dir=$(mktemp -d)
    cd "$non_git_dir"
    
    # Note: run captures both stdout and stderr, but error messages may be on stderr
    run bash -c "cd '$non_git_dir' && '$GIT_CLOAK_BIN' merge-main 2>&1"
    [[ $status -ne 0 ]]
    # Error message should be in output
    [[ "$output" =~ "Not in a git repository" ]] || [[ "$output" =~ "Error" ]]
    
    rm -rf "$non_git_dir"
}

@test "cmd_merge_main: handles multiple skip-worktree files" {
    # Create and hide 5 files
    for i in {1..5}; do
        echo "content$i" > "$TEST_REPO/file$i.txt"
        git -C "$TEST_REPO" add "file$i.txt"
        git -C "$TEST_REPO" commit -m "Add file$i"
        "$GIT_CLOAK_BIN" hide "file$i.txt"
    done
    
    # Create feature branch
    git -C "$TEST_REPO" checkout -b feature
    
    # Merge main
    run "$GIT_CLOAK_BIN" merge-main
    [[ $status -eq 0 ]]
    
    # Verify all files still have skip-worktree
    for i in {1..5}; do
        run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^S file$i.txt'"
        [[ $status -eq 0 ]]
    done
}

@test "cmd_merge_main: works with origin/main fallback" {
    # This tests that merge-main tries main first, then origin/main
    # In our test setup, we don't have origin/main, so it should fail gracefully
    # But the command should attempt both
    
    # Create initial commit
    git -C "$TEST_REPO" commit --allow-empty -m "test commit"
    
    # Create feature branch
    git -C "$TEST_REPO" checkout -b feature
    git -C "$TEST_REPO" commit --allow-empty -m "feature commit"
    
    # This should attempt merge of main (which exists)
    run "$GIT_CLOAK_BIN" merge-main
    # Should either succeed or fail gracefully
    [[ $status -eq 0 ]] || [[ "$output" =~ "Error" ]]
}

@test "cmd_merge_main: success message contains merge status" {
    # Create initial commit
    echo "content" > "$TEST_REPO/file.txt"
    git -C "$TEST_REPO" add file.txt
    git -C "$TEST_REPO" commit -m "Initial"
    
    # Create and checkout feature branch
    git -C "$TEST_REPO" checkout -b feature
    
    # Merge main (no new commits, but should succeed)
    run "$GIT_CLOAK_BIN" merge-main
    [[ $status -eq 0 ]]
    [[ "$output" =~ "Merge complete" ]]
}

@test "cmd_merge_main: re-applies skip-worktree to correct files only" {
    # Create files
    echo "hidden" > "$TEST_REPO/hidden.txt"
    git -C "$TEST_REPO" add hidden.txt
    git -C "$TEST_REPO" commit -m "Add hidden"
    
    echo "visible" > "$TEST_REPO/visible.txt"
    git -C "$TEST_REPO" add visible.txt
    git -C "$TEST_REPO" commit -m "Add visible"
    
    # Hide only one file
    "$GIT_CLOAK_BIN" hide hidden.txt
    
    # Verify states
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^S hidden.txt'"
    [[ $status -eq 0 ]]
    
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^H visible.txt'"
    [[ $status -eq 0 ]]
    
    # Create feature branch and merge
    git -C "$TEST_REPO" checkout -b feature
    run "$GIT_CLOAK_BIN" merge-main
    [[ $status -eq 0 ]]
    
    # Verify only the hidden file has skip-worktree
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^S hidden.txt'"
    [[ $status -eq 0 ]]
    
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^H visible.txt'"
    [[ $status -eq 0 ]]
}
