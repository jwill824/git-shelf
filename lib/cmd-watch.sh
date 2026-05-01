#!/usr/bin/env zsh
# Add file to watch-list for manual conflict resolution

cmd_watch() {
    local file="${1:-}"
    
    if [[ -z "$file" ]]; then
        echo "Usage: git cloak watch <file>" >&2
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
    
    # Initialize watch-list if missing
    local watch_list="$_PROJECT_ROOT/.git/personal/watch-list"
    mkdir -p "$(dirname "$watch_list")"
    touch "$watch_list"
    
    # Prevent duplicates
    if grep -q "^$file\$" "$watch_list" 2>/dev/null; then
        echo "Already watching: $file"
        return 0
    fi
    
    # Add to watch-list
    echo "$file" >> "$watch_list"
    echo "Watching: $file"
    return 0
}
