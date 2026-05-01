#!/usr/bin/env bash
# Initialize git-cloak for a repository

cmd_init() {
    # Resolve project root if not already set
    if [[ -z "$GIT_PROJECT_ROOT" ]]; then
        _resolve_project_root
        export GIT_PROJECT_ROOT="$_PROJECT_ROOT"
    fi
    
    # Verify we're in a git repository
    if ! git -C "$GIT_PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
        echo "Error: Not in a git repository" >&2
        return 1
    fi
    
    # Initialize .git/personal directory structure
    if ! _init_personal_dir; then
        echo "Error: Failed to initialize .git/personal directory" >&2
        return 1
    fi
    
    # Recompose ignore file (merge scopes)
    if ! _recompose_ignore; then
        echo "Error: Failed to recompose ignore file" >&2
        return 1
    fi
    
    # Configure git to use composed ignore file
    if ! git -C "$GIT_PROJECT_ROOT" config core.excludesFile .git/personal/ignore; then
        echo "Error: Failed to configure git core.excludesFile" >&2
        return 1
    fi
    
    # Verify git config was set
    local excludes_file
    excludes_file=$(git -C "$GIT_PROJECT_ROOT" config core.excludesFile)
    if [[ "$excludes_file" != ".git/personal/ignore" ]]; then
        echo "Error: Git config verification failed" >&2
        return 1
    fi
    
    echo "git cloak initialized successfully"
    return 0
}
