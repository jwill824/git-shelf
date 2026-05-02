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
    
    # Create a bare "remote" so pull tests work
    export TEST_REMOTE
    TEST_REMOTE="$(mktemp -d)/remote.git"
    git init --bare "$TEST_REMOTE"
    
    # Clone bare repo as our working copy
    export TEST_REPO
    TEST_REPO="$(mktemp -d)/myrepo"
    git clone "$TEST_REMOTE" "$TEST_REPO" 2>/dev/null
    
    # Initial tracked file + push to origin/main
    cd "$TEST_REPO"
    echo "# Test Repo" > README.md
    git add README.md
    git commit -m "Initial commit"
    git push -u origin main 2>/dev/null
}

parent_teardown() {
    cd / 2>/dev/null || true
    rm -rf "$HOME" "$(dirname "$TEST_REMOTE")" "$(dirname "$TEST_REPO")"
    export HOME="$ORIG_HOME"
}

# Helper to create a file in remote, push, then update local
_push_file_to_origin() {
    local filename="$1"
    local content="$2"
    
    cd "$TEST_REPO"
    echo "$content" > "$filename"
    git add "$filename"
    git commit -m "Add $filename"
    git push origin main >/dev/null 2>&1
}

# Basic refresh functionality

@test "cmd_refresh: performs git pull successfully" {
    # Add a file to remote
    _push_file_to_origin "remote_file.txt" "remote content"
    
    # In local repo, refresh should pull the new file
    cd "$TEST_REPO"
    run "$GIT_CLOAK" refresh
    [[ $status -eq 0 ]]
    [[ "$output" =~ "Refresh complete" ]]
    
    # Verify the file was pulled
    [[ -f "$TEST_REPO/remote_file.txt" ]]
}

@test "cmd_refresh: collects skip-worktree files before pull" {
    # Create and hide a file
    echo "config" > "$TEST_REPO/config.php"
    cd "$TEST_REPO"
    git add config.php
    git commit -m "Add config"
    
    # Initialize git-cloak and hide the file
    "$GIT_CLOAK" init >/dev/null 2>&1
    "$GIT_CLOAK" hide config.php >/dev/null 2>&1
    
    # Verify it's hidden
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^S config.php'"
    [[ $status -eq 0 ]]
    
    # Add another file to remote to trigger a pull
    _push_file_to_origin "other.txt" "other"
    
    # Run refresh
    run "$GIT_CLOAK" refresh
    [[ $status -eq 0 ]]
    
    # Verify skip-worktree was re-applied
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^S config.php'"
    [[ $status -eq 0 ]]
}

@test "cmd_refresh: re-applies skip-worktree after pull" {
    # Create and hide multiple files
    cd "$TEST_REPO"
    echo "config1" > config1.php
    echo "config2" > config2.php
    git add config1.php config2.php
    git commit -m "Add configs"
    
    # Initialize and hide
    "$GIT_CLOAK" init >/dev/null 2>&1
    "$GIT_CLOAK" hide config1.php >/dev/null 2>&1
    "$GIT_CLOAK" hide config2.php >/dev/null 2>&1
    
    # Verify both are hidden
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep -c '^S config'"
    [[ "$output" == "2" ]]
    
    # Push a change to remote
    _push_file_to_origin "new_file.txt" "new"
    
    # Refresh
    run "$GIT_CLOAK" refresh
    [[ $status -eq 0 ]]
    
    # Verify both are still hidden
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep -c '^S config'"
    [[ "$output" == "2" ]]
}

@test "cmd_refresh: handles stash/pop successfully" {
    # Create a file and make local changes
    cd "$TEST_REPO"
    echo "tracked" > tracked.txt
    git add tracked.txt
    git commit -m "Add tracked"
    
    # Make local changes
    echo "modified" >> tracked.txt
    
    # Add file to remote
    _push_file_to_origin "remote.txt" "remote"
    
    # Refresh should stash, pull, and pop
    run "$GIT_CLOAK" refresh
    [[ $status -eq 0 ]]
    
    # Local changes should still be there
    run grep -q "modified" "$TEST_REPO/tracked.txt"
    [[ $status -eq 0 ]]
}

@test "cmd_refresh: preserves skip-worktree with local changes" {
    # Create, commit, and hide a config file
    cd "$TEST_REPO"
    echo "original config" > config.php
    git add config.php
    git commit -m "Add config"
    
    "$GIT_CLOAK" init >/dev/null 2>&1
    "$GIT_CLOAK" hide config.php >/dev/null 2>&1
    
    # Modify the config locally (should be skipped in index)
    echo "local changes" >> config.php
    
    # Add remote changes
    _push_file_to_origin "other.txt" "other"
    
    # Refresh
    run "$GIT_CLOAK" refresh
    [[ $status -eq 0 ]]
    
    # Config should still be hidden and have local changes
    run bash -c "git -C '$TEST_REPO' ls-files -v | grep '^S config.php'"
    [[ $status -eq 0 ]]
    
    run grep -q "local changes" "$TEST_REPO/config.php"
    [[ $status -eq 0 ]]
}

@test "cmd_refresh: fails when not in a git repo" {
    local temp_dir
    temp_dir=$(mktemp -d)
    
    run bash -c "cd '$temp_dir' && '$GIT_CLOAK' refresh"
    [[ $status -ne 0 ]]
    
    rm -rf "$temp_dir"
}

@test "cmd_refresh: reports success message" {
    # Add a change to remote
    _push_file_to_origin "file.txt" "content"
    
    run bash -c "cd '$TEST_REPO' && '$GIT_CLOAK' refresh"
    [[ $status -eq 0 ]]
    [[ "$output" =~ "Refresh complete" ]]
}

@test "cmd_refresh: reports number of re-applied skip-worktree files" {
    # Create, commit, and hide files
    cd "$TEST_REPO"
    for i in {1..3}; do
        echo "config $i" > "config$i.php"
        git add "config$i.php"
        git commit -m "Add config$i"
    done
    
    "$GIT_CLOAK" init >/dev/null 2>&1
    for i in {1..3}; do
        "$GIT_CLOAK" hide "config$i.php" >/dev/null 2>&1
    done
    
    # Add remote change
    _push_file_to_origin "new.txt" "new"
    
    # Refresh and check output
    run "$GIT_CLOAK" refresh
    [[ $status -eq 0 ]]
    [[ "$output" =~ "Re-applied skip-worktree to 3 files" ]]
}

@test "cmd_refresh: initializes .git/personal directory if missing" {
    # Ensure .git/personal doesn't exist (it shouldn't in a fresh repo)
    rm -rf "$TEST_REPO/.git/personal"
    
    # Add remote change
    _push_file_to_origin "file.txt" "content"
    
    # Refresh
    run bash -c "cd '$TEST_REPO' && '$GIT_CLOAK' refresh"
    [[ $status -eq 0 ]]
    
    # .git/personal should now exist
    [[ -d "$TEST_REPO/.git/personal" ]]
}

@test "cmd_refresh: does nothing when no changes to pull" {
    cd "$TEST_REPO"
    
    # Ensure we're up to date
    git pull >/dev/null 2>&1
    
    run "$GIT_CLOAK" refresh
    [[ $status -eq 0 ]]
    [[ "$output" =~ "Refresh complete" ]]
}

@test "cmd_refresh: creates refresh-watched file" {
    # Create a skip-worktree file
    cd "$TEST_REPO"
    echo "config" > config.php
    git add config.php
    git commit -m "Add config"
    
    "$GIT_CLOAK" init >/dev/null 2>&1
    "$GIT_CLOAK" hide config.php >/dev/null 2>&1
    
    # Add remote change
    _push_file_to_origin "file.txt" "content"
    
    # Refresh
    run "$GIT_CLOAK" refresh
    [[ $status -eq 0 ]]
    
    # refresh-watched file should have been created
    [[ -f "$TEST_REPO/.git/personal/refresh-watched" ]]
}
