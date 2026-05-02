#!/usr/bin/env zsh
# Pull latest changes from remote while safely handling skip-worktree files

cmd_refresh() {
    # Resolve project root (common.sh already sourced by dispatcher)
    _resolve_project_root
    _resolve_workspace_root
    
    export GIT_PROJECT_ROOT="$_PROJECT_ROOT"
    export GIT_WORKSPACE_ROOT="$_WORKSPACE_ROOT"
    
    # Verify we're in a git repo - use subshell to avoid set -e issues
    local is_git_repo
    is_git_repo=$(git -C "$_PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1 && echo yes || echo no)
    if [[ "$is_git_repo" != "yes" ]]; then
        echo "Error: Not in a git repository" >&2
        return 1
    fi
    
    # Step 1: Get current branch
    local current_branch
    current_branch=$(git -C "$_PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ -z "$current_branch" ]]; then
        echo "Error: Unable to determine current branch" >&2
        return 1
    fi
    
    # Step 2: Collect and save skip-worktree files
    local refresh_watched="$_PROJECT_ROOT/.git/personal/refresh-watched"
    mkdir -p "$(dirname "$refresh_watched")"
    
    # Get current skip-worktree files
    git -C "$_PROJECT_ROOT" ls-files -v | grep '^S' | awk '{print $2}' > "$refresh_watched" 2>/dev/null || true
    local watched_count
    watched_count=$(wc -l < "$refresh_watched" 2>/dev/null || echo 0)
    watched_count=$((watched_count))
    
    # Step 3: Clear skip-worktree flags
    if [[ $watched_count -gt 0 ]]; then
        git -C "$_PROJECT_ROOT" ls-files -v | grep '^S' | awk '{print $2}' | xargs -I {} git -C "$_PROJECT_ROOT" update-index --no-skip-worktree {} 2>/dev/null || true
    fi
    
    # Step 4: Stash changes
    local stash_created=0
    if ! git -C "$_PROJECT_ROOT" diff-index --quiet HEAD -- 2>/dev/null; then
        git -C "$_PROJECT_ROOT" stash push -m "refresh backup" >/dev/null 2>&1
        stash_created=1
    fi
    
    # Step 5: Pull from remote
    local pull_status=0
    local pull_output
    pull_output=$(git -C "$_PROJECT_ROOT" pull 2>&1) || pull_status=1
    
    if [[ $pull_status -ne 0 ]]; then
        echo "Error: Pull failed" >&2
        echo "$pull_output" >&2
        return 1
    fi
    
    # Step 6: Pop stash if it was created
    if [[ $stash_created -eq 1 ]]; then
        git -C "$_PROJECT_ROOT" stash pop >/dev/null 2>&1 || {
            echo "Warning: Stash pop had conflicts, manual resolution may be needed"
        }
    fi
    
    # Step 7: Re-apply skip-worktree flags
    if [[ -f "$refresh_watched" ]] && [[ $watched_count -gt 0 ]]; then
        while IFS= read -r file; do
            if [[ -n "$file" ]]; then
                git -C "$_PROJECT_ROOT" update-index --skip-worktree "$file" 2>/dev/null || true
            fi
        done < "$refresh_watched"
    fi
    
    # Step 8: Report summary
    echo "Pulling from origin/$current_branch..."
    echo "Refresh complete"
    if [[ $watched_count -gt 0 ]]; then
        echo "Re-applied skip-worktree to $watched_count files"
    fi
    
    return 0
}
