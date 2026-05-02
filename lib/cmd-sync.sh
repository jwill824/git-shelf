#!/usr/bin/env zsh
# Re-sync skip-worktree flags from project-ignore
# Clears all skip-worktree flags and re-applies them

cmd_sync() {
    _resolve_project_root
    _resolve_workspace_root
    
    export GIT_PROJECT_ROOT="$_PROJECT_ROOT"
    export GIT_WORKSPACE_ROOT="$_WORKSPACE_ROOT"
    
    if [[ -z "$_PROJECT_ROOT" ]] || ! git -C "$_PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
        echo "Error: Not in a git repository" >&2
        return 1
    fi
    
    local project_ignore="$_PROJECT_ROOT/.git/personal/project-ignore"
    
    if [[ ! -f "$project_ignore" ]]; then
        echo "No files to sync"
        return 0
    fi
    
    if ! _recompose_ignore; then
        echo "Error: Failed to recompose ignore file" >&2
        return 1
    fi
    
    local all_skip_worktree
    all_skip_worktree=$(git -C "$_PROJECT_ROOT" ls-files -v | grep '^S' | awk '{print $2}' 2>/dev/null || true)
    
    if [[ -n "$all_skip_worktree" ]]; then
        while IFS= read -r file; do
            git -C "$_PROJECT_ROOT" update-index --no-skip-worktree "$file" 2>/dev/null || true
        done <<< "$all_skip_worktree"
    fi
    
    local count=0
    if [[ -s "$project_ignore" ]]; then
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            [[ "$file" =~ ^#.*$ ]] && continue
            
            if git -C "$_PROJECT_ROOT" ls-files --error-unmatch "$file" >/dev/null 2>&1; then
                if git -C "$_PROJECT_ROOT" update-index --skip-worktree "$file" 2>/dev/null; then
                    count=$((count + 1))
                fi
            fi
        done < "$project_ignore"
    fi
    
    echo "Re-synced skip-worktree flags"
    if [[ $count -gt 0 ]]; then
        echo "Updated $count files"
    fi
    return 0
}
