#!/usr/bin/env zsh
# Remove file from watch-list

cmd_unwatch() {
    local file="${1:-}"
    
    if [[ -z "$file" ]]; then
        echo "Usage: git cloak unwatch <file>" >&2
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
    
    local watch_list="$_PROJECT_ROOT/.git/personal/watch-list"
    
    # Check if file is in watch-list
    if ! grep -q "^$file\$" "$watch_list" 2>/dev/null; then
        echo "Error: File '$file' is not in watch-list" >&2
        return 1
    fi
    
    # Remove from watch-list (use temporary file for sed compatibility)
    local tmp_file=$(mktemp)
    grep -v "^$file\$" "$watch_list" > "$tmp_file"
    mv "$tmp_file" "$watch_list"
    
    echo "Unwatching: $file"
    return 0
}
