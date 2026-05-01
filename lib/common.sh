#!/usr/bin/env zsh
# Shared utilities - full implementation in Task 3
# For now, define path resolution stubs

_resolve_project_root() {
    # TODO: Implement in Task 3
    git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || echo "$PWD"
}

_resolve_workspace_root() {
    # TODO: Implement in Task 3
    echo "$PWD"
}

_recompose_ignore() {
    # TODO: Implement in Task 3
    echo "TODO: recompose_ignore"
}
