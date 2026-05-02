#!/usr/bin/env bash
# Shared utilities for git-cloak
# Provides path resolution and ignore file composition

# Find the git repository root (current project)
# Sets global: _PROJECT_ROOT
_resolve_project_root() {
    local result
    result=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || echo "")
    if [[ -z "$result" ]]; then
        _PROJECT_ROOT="$PWD"
    else
        _PROJECT_ROOT="$result"
    fi
}

# Find the workspace root (ancestor directory with .git-cloak/ marker)
# Workspace is optional; sets global: _WORKSPACE_ROOT or ""
# Assumes _PROJECT_ROOT is already set
_resolve_workspace_root() {
    _WORKSPACE_ROOT=""
    
    if [[ -z "$_PROJECT_ROOT" ]]; then
        return 0
    fi
    
    local current_dir
    current_dir=$(dirname "$_PROJECT_ROOT")
    
    while [[ "$current_dir" != "/" ]]; do
        if [[ -d "$current_dir/.git-cloak" ]]; then
            _WORKSPACE_ROOT="$current_dir"
            return 0
        fi
        current_dir=$(dirname "$current_dir")
    done
    
    _WORKSPACE_ROOT=""
    return 0
}

# Compose ignore files: merge global, workspace, and project scope into .git/personal/ignore
# Reads from: ~/.config/git-cloak/ignore, $WORKSPACE_ROOT/.git-cloak/ignore, .git/personal/project-ignore
# Writes to: .git/personal/ignore
_recompose_ignore() {
    if [[ -z "$GIT_PROJECT_ROOT" ]]; then
        return 1
    fi
    
    # Ensure .git/personal directory exists
    mkdir -p "$GIT_PROJECT_ROOT/.git/personal" || return 1
    
    local ignore_content=""
    local global_ignore="$HOME/.config/git-cloak/ignore"
    local workspace_ignore=""
    local project_ignore="$GIT_PROJECT_ROOT/.git/personal/project-ignore"
    
    # Add global scope if it exists
    if [[ -f "$global_ignore" ]]; then
        ignore_content+=$(cat "$global_ignore")
        ignore_content+=$'\n'
    fi
    
    # Add workspace scope if it exists and workspace is set
    if [[ -n "$GIT_WORKSPACE_ROOT" ]]; then
        workspace_ignore="$GIT_WORKSPACE_ROOT/.git-cloak/ignore"
        if [[ -f "$workspace_ignore" ]]; then
            ignore_content+=$(cat "$workspace_ignore")
            ignore_content+=$'\n'
        fi
    fi
    
    # Add project scope if it exists
    if [[ -f "$project_ignore" ]]; then
        ignore_content+=$(cat "$project_ignore")
        ignore_content+=$'\n'
    fi
    
    # Write merged content to .git/personal/ignore
    echo -n "$ignore_content" > "$GIT_PROJECT_ROOT/.git/personal/ignore"
    return 0
}

# Initialize .git/personal directory structure
_init_personal_dir() {
    if [[ -z "$GIT_PROJECT_ROOT" ]]; then
        return 1
    fi
    
    # Create .git/personal if not exists
    mkdir -p "$GIT_PROJECT_ROOT/.git/personal" || return 1
    
    # Create project-ignore stub if not exists
    if [[ ! -f "$GIT_PROJECT_ROOT/.git/personal/project-ignore" ]]; then
        touch "$GIT_PROJECT_ROOT/.git/personal/project-ignore"
    fi
    
    return 0
}
