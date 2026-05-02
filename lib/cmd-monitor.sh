#!/usr/bin/env bash
# Manage .git/personal/watch-list for files that trigger manual review pause

cmd_monitor() {
    local subcommand="${1:-}"
    local filename="${2:-}"
    
    # Resolve project root (common.sh already sourced by dispatcher)
    _resolve_project_root
    _resolve_workspace_root
    
    # Verify we're in a git repo
    if [[ -z "$_PROJECT_ROOT" ]] || ! git -C "$_PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
        echo "Error: Not in a git repository" >&2
        return 1
    fi
    
    local watch_list="$_PROJECT_ROOT/.git/personal/watch-list"
    
    # Error if no subcommand provided
    if [[ -z "$subcommand" ]]; then
        echo "Usage: git cloak monitor <add|remove|list> [filename]" >&2
        return 1
    fi
    
    case "$subcommand" in
        add)
            if [[ -z "$filename" ]]; then
                echo "Usage: git cloak monitor add <filename>" >&2
                return 1
            fi
            _monitor_add "$watch_list" "$filename"
            return $?
            ;;
        remove)
            if [[ -z "$filename" ]]; then
                echo "Usage: git cloak monitor remove <filename>" >&2
                return 1
            fi
            _monitor_remove "$watch_list" "$filename"
            return $?
            ;;
        list)
            _monitor_list "$watch_list"
            return $?
            ;;
        *)
            echo "Usage: git cloak monitor <add|remove|list> [filename]" >&2
            return 1
            ;;
    esac
}

# Add a file to watch-list (idempotent)
_monitor_add() {
    local watch_list="$1"
    local filename="$2"
    
    # Ensure watch-list file exists
    if [[ ! -f "$watch_list" ]]; then
        touch "$watch_list"
    fi
    
    # Check if already in list (exact match)
    if grep -qxF "$filename" "$watch_list"; then
        echo "Already in watch list: $filename"
        return 0
    fi
    
    # Add to watch-list
    echo "$filename" >> "$watch_list"
    echo "Added to watch list: $filename"
    return 0
}

# Remove a file from watch-list (idempotent)
_monitor_remove() {
    local watch_list="$1"
    local filename="$2"
    
    # If watch-list doesn't exist, file is not in list
    if [[ ! -f "$watch_list" ]]; then
        echo "Not in watch list: $filename"
        return 0
    fi
    
    # Check if in list
    if ! grep -qxF "$filename" "$watch_list"; then
        echo "Not in watch list: $filename"
        return 0
    fi
    
    # Remove from watch-list (using sed for cross-platform compatibility)
    # macOS sed requires empty string after -i
    sed -i '' "/^$(printf '%s\n' "$filename" | sed 's:[[][\\/.*^$]:\\&:g')$/d" "$watch_list"
    echo "Removed from watch list: $filename"
    return 0
}

# List all monitored files
_monitor_list() {
    local watch_list="$1"
    
    # If watch-list doesn't exist or is empty
    if [[ ! -f "$watch_list" ]] || [[ ! -s "$watch_list" ]]; then
        echo "Watch list is empty"
        return 0
    fi
    
    # Display watch-list
    echo "Files being watched for manual conflict resolution:"
    cat "$watch_list" | nl -v 1
    return 0
}
