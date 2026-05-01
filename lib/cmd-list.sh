#!/usr/bin/env zsh
# Show list of files being watched for manual conflict resolution

cmd_list() {
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
    
    # Check if watch-list exists and has content
    if [[ ! -f "$watch_list" ]] || [[ ! -s "$watch_list" ]]; then
        echo "No files are being watched"
        return 0
    fi
    
    # Display watch-list
    echo "Files being watched for manual conflict resolution:"
    cat "$watch_list" | nl -v 1
    return 0
}
