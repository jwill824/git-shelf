#!/usr/bin/env zsh
# Safe branch switch with skip-worktree handling
# Usage: git cloak switch <branch>
#        git cloak switch --restore-watch  (after manual conflict resolution)

cmd_switch() {
    # Resolve project and workspace roots
    _resolve_project_root
    _resolve_workspace_root
    
    export GIT_PROJECT_ROOT="$_PROJECT_ROOT"
    export GIT_WORKSPACE_ROOT="$_WORKSPACE_ROOT"
    
    # Verify we're in a git repo
    if [[ -z "$_PROJECT_ROOT" ]] || ! git -C "$_PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
        echo "Error: Not in a git repository" >&2
        return 1
    fi
    
    local _saved_watch="$_PROJECT_ROOT/.git/personal/switch-watched"
    local _watch_list="$_PROJECT_ROOT/.git/personal/watch-list"
    
    _is_monitored() {
        local _f="$1"
        [[ -f "$_watch_list" ]] && grep -v '^\s*#' "$_watch_list" | grep -qxF "$_f"
    }
    
    # --restore-watch: re-apply skip-worktree after manual conflict resolution
    if [[ "${1:-}" == "--restore-watch" ]]; then
        local _remaining
        _remaining=($(git -C "$_PROJECT_ROOT" diff --name-only --diff-filter=U 2>/dev/null))
        if [[ ${#_remaining[@]} -gt 0 ]]; then
            echo "Unresolved conflicts remain:" >&2
            for _f in "${_remaining[@]}"; do echo "  $_f" >&2; done
            echo "Resolve them, stage with 'git add <file>', then run: git cloak switch --restore-watch" >&2
            return 1
        fi
        if [[ ! -f "$_saved_watch" ]]; then
            echo "Error: no saved watch list found at $_saved_watch" >&2
            echo "Re-apply skip-worktree manually with: git cloak watch <file>" >&2
            return 1
        fi
        local _watched
        _watched=(${(f)"$(<$_saved_watch)"})
        echo "Unstaging all changes..."
        git -C "$_PROJECT_ROOT" restore --staged . 2>/dev/null || true
        echo "Re-applying skip-worktree to ${#_watched[@]} files..."
        git -C "$_PROJECT_ROOT" update-index --skip-worktree "${_watched[@]}"
        rm -f "$_saved_watch"
        echo "Done."
        return 0
    fi
    
    if [[ -z "${1:-}" ]]; then
        echo "Usage: git cloak switch <branch>" >&2
        return 1
    fi
    
    local _target="$1"
    
    # Verify the branch exists locally or on origin
    if ! git -C "$_PROJECT_ROOT" rev-parse --verify "$_target" &>/dev/null && \
       ! git -C "$_PROJECT_ROOT" rev-parse --verify "origin/$_target" &>/dev/null; then
        echo "Error: branch '$_target' not found locally or on origin." >&2
        return 1
    fi
    
    # Collect skip-worktree files
    local _watched
    _watched=($(git -C "$_PROJECT_ROOT" ls-files -v | grep '^S' | awk '{print $2}'))
    
    if [[ ${#_watched[@]} -eq 0 ]]; then
        echo "No skip-worktree files found. Running plain switch..."
        git -C "$_PROJECT_ROOT" switch "$_target"
        return $?
    fi
    
    # Save list for --restore-watch
    printf '%s\n' "${_watched[@]}" > "$_saved_watch"
    
    echo "Clearing skip-worktree on ${#_watched[@]} files..."
    git -C "$_PROJECT_ROOT" update-index --no-skip-worktree "${_watched[@]}"
    
    echo "Stashing local changes..."
    git -C "$_PROJECT_ROOT" stash push -m "git-cloak switch auto-stash ($_target)" >/dev/null 2>&1
    local _stash_created=$?
    
    echo "Switching to $_target..."
    git -C "$_PROJECT_ROOT" switch "$_target"
    local _switch_exit=$?
    
    if [[ $_switch_exit -ne 0 ]]; then
        echo "Switch failed. Restoring stash and re-applying skip-worktree..."
        if [[ $_stash_created -eq 0 ]]; then
            git -C "$_PROJECT_ROOT" stash pop >/dev/null 2>&1 || true
        fi
        git -C "$_PROJECT_ROOT" update-index --skip-worktree "${_watched[@]}" 2>/dev/null || true
        rm -f "$_saved_watch"
        return $_switch_exit
    fi
    
    # If stash was created, pop it
    if [[ $_stash_created -eq 0 ]]; then
        echo "Restoring local changes..."
        git -C "$_PROJECT_ROOT" stash pop >/dev/null 2>&1
        local _stash_exit=$?
        
        if [[ $_stash_exit -ne 0 ]]; then
            local _conflicted
            _conflicted=($(git -C "$_PROJECT_ROOT" diff --name-only --diff-filter=U 2>/dev/null))
            local _monitored_conflicts=()
            
            for _file in "${_conflicted[@]}"; do
                if _is_monitored "$_file"; then
                    _monitored_conflicts+=("$_file")
                    echo "MONITOR: $_file has conflicts — needs manual review"
                else
                    git -C "$_PROJECT_ROOT" checkout --theirs "$_file" 2>/dev/null || true
                    git -C "$_PROJECT_ROOT" add "$_file" 2>/dev/null || true
                    echo "Auto-resolved (kept local): $_file"
                fi
            done
            
            if [[ ${#_monitored_conflicts[@]} -gt 0 ]]; then
                echo ""
                echo "Files needing manual resolution (in monitor list):"
                for _f in "${_monitored_conflicts[@]}"; do
                    echo "  $_f"
                done
                echo ""
                echo "Resolve each file, then: git add <file> && git cloak switch --restore-watch"
                return 1
            fi
        fi
    fi
    
    echo "Unstaging all changes..."
    git -C "$_PROJECT_ROOT" restore --staged . 2>/dev/null || true
    echo "Re-applying skip-worktree..."
    git -C "$_PROJECT_ROOT" update-index --skip-worktree "${_watched[@]}"
    rm -f "$_saved_watch"
    echo ""
    echo "Done. Now on $(git -C "$_PROJECT_ROOT" branch --show-current). Local changes preserved, skip-worktree re-applied."
    return 0
}
