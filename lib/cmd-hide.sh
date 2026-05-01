#!/usr/bin/env zsh
# Hide a tracked file: mark skip-worktree and add to project-ignore

cmd_hide() {
    local file="${1:-}"
    
    if [[ -z "$file" ]]; then
        echo "Usage: git cloak hide <file>" >&2
        return 1
    fi
    
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
    
    # Check if file exists in repo
    if ! git -C "$_PROJECT_ROOT" ls-files --error-unmatch "$file" >/dev/null 2>&1; then
        echo "Error: File '$file' is not tracked in git" >&2
        return 1
    fi
    
    # Mark as skip-worktree
    if ! git -C "$_PROJECT_ROOT" update-index --skip-worktree "$file" 2>/dev/null; then
        echo "Error: Failed to mark '$file' as skip-worktree" >&2
        return 1
    fi
    
    # Add to project-ignore (prevent duplicates)
    local project_ignore="$_PROJECT_ROOT/.git/personal/project-ignore"
    if ! grep -q "^$file\$" "$project_ignore" 2>/dev/null; then
        echo "$file" >> "$project_ignore"
    fi
    
    # Recompose ignore file
    if ! _recompose_ignore; then
        echo "Error: Failed to recompose ignore file" >&2
        return 1
    fi
    
    echo "Hidden: $file (skip-worktree + project-ignore)"
    return 0
}
