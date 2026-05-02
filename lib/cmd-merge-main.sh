#!/usr/bin/env zsh
# Merge main branch while handling skip-worktree files

cmd_merge_main() {
    # Resolve project root (common.sh already sourced by dispatcher)
    _resolve_project_root
    _resolve_workspace_root
    
    export GIT_PROJECT_ROOT="$_PROJECT_ROOT"
    export GIT_WORKSPACE_ROOT="$_WORKSPACE_ROOT"
    
    # Verify we're in a git repo
    if [[ -z "$_PROJECT_ROOT" ]] || ! git -C "$_PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
        echo "Error: Not in a git repository" >&2
        return 1
    fi
    
    # Step 1: Collect and save skip-worktree files
    local merge_main_watched="$_PROJECT_ROOT/.git/personal/merge-main-watched"
    mkdir -p "$(dirname "$merge_main_watched")"
    
    # Get current skip-worktree files
    git -C "$_PROJECT_ROOT" ls-files -v | grep '^S' | awk '{print $2}' > "$merge_main_watched"
    local watched_count
    watched_count=$(wc -l < "$merge_main_watched" 2>/dev/null || echo 0)
    watched_count=$((watched_count))
    
    # Step 2: Clear skip-worktree flags
    if [[ $watched_count -gt 0 ]]; then
        git -C "$_PROJECT_ROOT" ls-files -v | grep '^S' | awk '{print $2}' | xargs -I {} git -C "$_PROJECT_ROOT" update-index --no-skip-worktree {} 2>/dev/null || true
    fi
    
    # Step 3: Stash changes
    local stash_created=0
    if ! git -C "$_PROJECT_ROOT" diff-index --quiet HEAD --; then
        git -C "$_PROJECT_ROOT" stash push -m "merge-main backup" >/dev/null 2>&1
        stash_created=1
    fi
    
    # Step 4: Attempt merge main
    local merge_status=0
    local merge_output
    
    # Try to merge main first, fall back to origin/main
    merge_output=$(git -C "$_PROJECT_ROOT" merge main 2>&1) || merge_status=1
    
    if [[ $merge_status -ne 0 ]]; then
        # Try origin/main
        merge_status=0
        merge_output=$(git -C "$_PROJECT_ROOT" merge origin/main 2>&1) || merge_status=1
    fi
    
    if [[ $merge_status -ne 0 ]]; then
        echo "Error: Merge failed" >&2
        echo "$merge_output" >&2
        return 1
    fi
    
    # Step 5: Pop stash if it was created
    if [[ $stash_created -eq 1 ]]; then
        git -C "$_PROJECT_ROOT" stash pop >/dev/null 2>&1 || {
            echo "Warning: Stash pop had conflicts, manual resolution may be needed"
        }
    fi
    
    # Step 6: Re-apply skip-worktree flags
    if [[ -f "$merge_main_watched" ]] && [[ $watched_count -gt 0 ]]; then
        while IFS= read -r file; do
            if [[ -n "$file" ]]; then
                git -C "$_PROJECT_ROOT" update-index --skip-worktree "$file" 2>/dev/null || true
            fi
        done < "$merge_main_watched"
    fi
    
    # Step 7: Report summary
    echo "Merge complete: main merged successfully"
    if [[ $watched_count -gt 0 ]]; then
        echo "Re-applied skip-worktree to $watched_count files"
    fi
    
    return 0
}
