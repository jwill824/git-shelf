#!/usr/bin/env bats

load 'setup'

setup() {
    # Load parent setup
    parent_setup
    
    # Create a test workspace directory with .git-cloak marker
    export TEST_WORKSPACE
    TEST_WORKSPACE="$(mktemp -d)"
    mkdir -p "$TEST_WORKSPACE/.git-cloak"
    
    # Create a test project inside the workspace (a git repo)
    export TEST_PROJECT
    TEST_PROJECT="$TEST_WORKSPACE/project"
    mkdir -p "$TEST_PROJECT"
    
    cd "$TEST_PROJECT"
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    git commit --allow-empty -m "init"
    
    # Normalize paths to match what git returns (includes /private on macOS)
    TEST_PROJECT="$(cd "$TEST_PROJECT" && git rev-parse --show-toplevel)"
    # Normalize workspace by walking up from project
    TEST_WORKSPACE="$(cd "$(dirname "$TEST_PROJECT")" && pwd)"
    
    # Export paths for tests
    export GIT_PROJECT_ROOT="$TEST_PROJECT"
    export GIT_WORKSPACE_ROOT="$TEST_WORKSPACE"
    
    # Create .git/personal directory
    mkdir -p "$GIT_PROJECT_ROOT/.git/personal"
    
    # Export the path to common.sh for tests
    export COMMON_SH
    COMMON_SH="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/lib/common.sh"
}

parent_setup() {
    # Isolate from real HOME
    export ORIG_HOME="$HOME"
    export HOME
    HOME="$(mktemp -d)"
    export XDG_CONFIG_HOME="$HOME/.config"
    
    # Minimal git identity
    git config --global user.name "Test User"
    git config --global user.email "test@example.com"
    git config --global init.defaultBranch main
}

teardown() {
    cd / 2>/dev/null || true
    rm -rf "$TEST_WORKSPACE" "$HOME"
    export HOME="$ORIG_HOME"
}

# ============================================================================
# _resolve_project_root tests
# ============================================================================

@test "common: _resolve_project_root returns project root when in git repo" {
    cd "$TEST_PROJECT"
    run bash -c "source '$COMMON_SH' && _resolve_project_root && echo \$_PROJECT_ROOT"
    [ $status -eq 0 ]
    [[ "$output" == "$TEST_PROJECT" ]]
}

@test "common: _resolve_project_root fails when not in git repo" {
    cd "$HOME"
    run bash -c "source '$COMMON_SH' && _resolve_project_root && echo \$_PROJECT_ROOT"
    # Should not find a git repo in HOME (empty temp dir)
    [[ "$output" == "$HOME" ]]  # Falls back to PWD
}

@test "common: _resolve_project_root sets _PROJECT_ROOT global variable" {
    cd "$TEST_PROJECT"
    run bash -c "source '$COMMON_SH' && _resolve_project_root && [[ -n \$_PROJECT_ROOT ]] && echo 'set'"
    [ $status -eq 0 ]
    [[ "$output" == "set" ]]
}

@test "common: _resolve_project_root works from subdirectory" {
    mkdir -p "$TEST_PROJECT/subdir/nested"
    cd "$TEST_PROJECT/subdir/nested"
    run bash -c "source '$COMMON_SH' && _resolve_project_root && echo \$_PROJECT_ROOT"
    [ $status -eq 0 ]
    [[ "$output" == "$TEST_PROJECT" ]]
}

# ============================================================================
# _resolve_workspace_root tests
# ============================================================================

@test "common: _resolve_workspace_root finds workspace marker" {
    cd "$TEST_PROJECT"
    run bash -c "
        export GIT_PROJECT_ROOT='$GIT_PROJECT_ROOT'
        source '$COMMON_SH'
        _resolve_project_root
        _resolve_workspace_root
        echo \$_WORKSPACE_ROOT
    "
    [ $status -eq 0 ]
    [[ "$output" == "$TEST_WORKSPACE" ]]
}

@test "common: _resolve_workspace_root sets _WORKSPACE_ROOT global" {
    cd "$TEST_PROJECT"
    run bash -c "
        export GIT_PROJECT_ROOT='$GIT_PROJECT_ROOT'
        source '$COMMON_SH'
        _resolve_project_root
        _resolve_workspace_root
        [[ -n \$_WORKSPACE_ROOT ]] && echo 'set'
    "
    [ $status -eq 0 ]
    [[ "$output" == "set" ]]
}

@test "common: _resolve_workspace_root returns empty when no marker found" {
    # Create a temporary directory without .git-cloak marker
    export NO_MARKER_DIR
    NO_MARKER_DIR="$(mktemp -d)"
    cd "$NO_MARKER_DIR"
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    run bash -c "
        export GIT_PROJECT_ROOT='$NO_MARKER_DIR'
        source '$COMMON_SH'
        _resolve_project_root
        _resolve_workspace_root
        [[ -z \$_WORKSPACE_ROOT ]] && echo 'empty'
    "
    [ $status -eq 0 ]
    [[ "$output" == "empty" ]]
    
    rm -rf "$NO_MARKER_DIR"
}

@test "common: _resolve_workspace_root walks up from project root" {
    # Create nested project structure: WORKSPACE/.git-cloak/config, WORKSPACE/inner/project/
    export INNER_PROJECT
    INNER_PROJECT="$TEST_WORKSPACE/inner/deep/project"
    mkdir -p "$INNER_PROJECT"
    cd "$INNER_PROJECT"
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    git commit --allow-empty -m "init"
    
    run bash -c "
        export GIT_PROJECT_ROOT='$INNER_PROJECT'
        source '$COMMON_SH'
        _resolve_project_root
        _resolve_workspace_root
        echo \$_WORKSPACE_ROOT
    "
    [ $status -eq 0 ]
    [[ "$output" == "$TEST_WORKSPACE" ]]
}

@test "common: _resolve_workspace_root stops at first .git-cloak" {
    # Create two marker directories (nested) and verify it stops at first
    mkdir -p "$TEST_WORKSPACE/nested/.git-cloak"
    export NESTED_PROJECT
    NESTED_PROJECT="$TEST_WORKSPACE/nested/deeper/project"
    mkdir -p "$NESTED_PROJECT"
    cd "$NESTED_PROJECT"
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    git commit --allow-empty -m "init"
    
    run bash -c "
        export GIT_PROJECT_ROOT='$NESTED_PROJECT'
        source '$COMMON_SH'
        _resolve_project_root
        _resolve_workspace_root
        echo \$_WORKSPACE_ROOT
    "
    [ $status -eq 0 ]
    # Should find the nested marker, not the outer one
    [[ "$output" == "$TEST_WORKSPACE/nested" ]]
}

# ============================================================================
# _recompose_ignore tests
# ============================================================================

@test "common: _recompose_ignore creates .git/personal if missing" {
    rm -rf "$GIT_PROJECT_ROOT/.git/personal"
    cd "$GIT_PROJECT_ROOT"
    run bash -c "
        export GIT_PROJECT_ROOT='$GIT_PROJECT_ROOT'
        export GIT_WORKSPACE_ROOT='$GIT_WORKSPACE_ROOT'
        source '$COMMON_SH'
        _recompose_ignore
        [[ -d \$GIT_PROJECT_ROOT/.git/personal ]] && echo 'created'
    "
    [ $status -eq 0 ]
    [[ "$output" == "created" ]]
}

@test "common: _recompose_ignore merges global ignore" {
    mkdir -p "$HOME/.config/git-cloak"
    cat > "$HOME/.config/git-cloak/ignore" <<'EOF'
# Global scope
*.log
EOF
    
    cd "$GIT_PROJECT_ROOT"
    run bash -c "
        export GIT_PROJECT_ROOT='$GIT_PROJECT_ROOT'
        export GIT_WORKSPACE_ROOT='$GIT_WORKSPACE_ROOT'
        source '$COMMON_SH'
        _recompose_ignore
        cat \$GIT_PROJECT_ROOT/.git/personal/ignore
    "
    [ $status -eq 0 ]
    [[ "$output" =~ "*.log" ]]
}

@test "common: _recompose_ignore merges workspace ignore" {
    mkdir -p "$GIT_WORKSPACE_ROOT/.git-cloak"
    cat > "$GIT_WORKSPACE_ROOT/.git-cloak/ignore" <<'EOF'
# Workspace scope
*.tmp
EOF
    
    cd "$GIT_PROJECT_ROOT"
    run bash -c "
        export GIT_PROJECT_ROOT='$GIT_PROJECT_ROOT'
        export GIT_WORKSPACE_ROOT='$GIT_WORKSPACE_ROOT'
        source '$COMMON_SH'
        _recompose_ignore
        cat \$GIT_PROJECT_ROOT/.git/personal/ignore
    "
    [ $status -eq 0 ]
    [[ "$output" =~ "*.tmp" ]]
}

@test "common: _recompose_ignore merges project ignore" {
    mkdir -p "$GIT_PROJECT_ROOT/.git/personal"
    cat > "$GIT_PROJECT_ROOT/.git/personal/project-ignore" <<'EOF'
# Project scope
*.swp
EOF
    
    cd "$GIT_PROJECT_ROOT"
    run bash -c "
        export GIT_PROJECT_ROOT='$GIT_PROJECT_ROOT'
        export GIT_WORKSPACE_ROOT='$GIT_WORKSPACE_ROOT'
        source '$COMMON_SH'
        _recompose_ignore
        cat \$GIT_PROJECT_ROOT/.git/personal/ignore
    "
    [ $status -eq 0 ]
    [[ "$output" =~ "*.swp" ]]
}

@test "common: _recompose_ignore merges all three scopes" {
    mkdir -p "$HOME/.config/git-cloak"
    cat > "$HOME/.config/git-cloak/ignore" <<'EOF'
# Global
*.log
EOF
    
    mkdir -p "$GIT_WORKSPACE_ROOT/.git-cloak"
    cat > "$GIT_WORKSPACE_ROOT/.git-cloak/ignore" <<'EOF'
# Workspace
*.tmp
EOF
    
    mkdir -p "$GIT_PROJECT_ROOT/.git/personal"
    cat > "$GIT_PROJECT_ROOT/.git/personal/project-ignore" <<'EOF'
# Project
*.swp
EOF
    
    cd "$GIT_PROJECT_ROOT"
    run bash -c "
        export GIT_PROJECT_ROOT='$GIT_PROJECT_ROOT'
        export GIT_WORKSPACE_ROOT='$GIT_WORKSPACE_ROOT'
        source '$COMMON_SH'
        _recompose_ignore
        cat \$GIT_PROJECT_ROOT/.git/personal/ignore
    "
    [ $status -eq 0 ]
    [[ "$output" =~ "*.log" ]]
    [[ "$output" =~ "*.tmp" ]]
    [[ "$output" =~ "*.swp" ]]
}

@test "common: _recompose_ignore handles missing global ignore" {
    mkdir -p "$GIT_WORKSPACE_ROOT/.git-cloak"
    cat > "$GIT_WORKSPACE_ROOT/.git-cloak/ignore" <<'EOF'
*.tmp
EOF
    
    mkdir -p "$GIT_PROJECT_ROOT/.git/personal"
    cat > "$GIT_PROJECT_ROOT/.git/personal/project-ignore" <<'EOF'
*.swp
EOF
    
    cd "$GIT_PROJECT_ROOT"
    run bash -c "
        export GIT_PROJECT_ROOT='$GIT_PROJECT_ROOT'
        export GIT_WORKSPACE_ROOT='$GIT_WORKSPACE_ROOT'
        source '$COMMON_SH'
        _recompose_ignore
        echo 'success'
    "
    [ $status -eq 0 ]
    [[ "$output" =~ "success" ]]
}

@test "common: _recompose_ignore handles missing workspace ignore" {
    mkdir -p "$HOME/.config/git-cloak"
    cat > "$HOME/.config/git-cloak/ignore" <<'EOF'
*.log
EOF
    
    mkdir -p "$GIT_PROJECT_ROOT/.git/personal"
    cat > "$GIT_PROJECT_ROOT/.git/personal/project-ignore" <<'EOF'
*.swp
EOF
    
    # Don't create workspace ignore
    cd "$GIT_PROJECT_ROOT"
    run bash -c "
        export GIT_PROJECT_ROOT='$GIT_PROJECT_ROOT'
        export GIT_WORKSPACE_ROOT='$GIT_WORKSPACE_ROOT'
        source '$COMMON_SH'
        _recompose_ignore
        echo 'success'
    "
    [ $status -eq 0 ]
    [[ "$output" =~ "success" ]]
}

@test "common: _recompose_ignore handles missing project ignore" {
    mkdir -p "$HOME/.config/git-cloak"
    cat > "$HOME/.config/git-cloak/ignore" <<'EOF'
*.log
EOF
    
    mkdir -p "$GIT_WORKSPACE_ROOT/.git-cloak"
    cat > "$GIT_WORKSPACE_ROOT/.git-cloak/ignore" <<'EOF'
*.tmp
EOF
    
    # Don't create project ignore
    cd "$GIT_PROJECT_ROOT"
    run bash -c "
        export GIT_PROJECT_ROOT='$GIT_PROJECT_ROOT'
        export GIT_WORKSPACE_ROOT='$GIT_WORKSPACE_ROOT'
        source '$COMMON_SH'
        _recompose_ignore
        echo 'success'
    "
    [ $status -eq 0 ]
    [[ "$output" =~ "success" ]]
}

@test "common: _recompose_ignore handles all missing ignore files" {
    mkdir -p "$GIT_PROJECT_ROOT/.git/personal"
    
    cd "$GIT_PROJECT_ROOT"
    run bash -c "
        export GIT_PROJECT_ROOT='$GIT_PROJECT_ROOT'
        export GIT_WORKSPACE_ROOT='$GIT_WORKSPACE_ROOT'
        source '$COMMON_SH'
        _recompose_ignore
        echo 'success'
    "
    [ $status -eq 0 ]
    [[ "$output" =~ "success" ]]
}

@test "common: _recompose_ignore preserves comments" {
    mkdir -p "$HOME/.config/git-cloak"
    cat > "$HOME/.config/git-cloak/ignore" <<'EOF'
# Global patterns
*.log
EOF
    
    mkdir -p "$GIT_PROJECT_ROOT/.git/personal"
    cat > "$GIT_PROJECT_ROOT/.git/personal/project-ignore" <<'EOF'
# Project patterns
*.swp
EOF
    
    cd "$GIT_PROJECT_ROOT"
    run bash -c "
        export GIT_PROJECT_ROOT='$GIT_PROJECT_ROOT'
        export GIT_WORKSPACE_ROOT='$GIT_WORKSPACE_ROOT'
        source '$COMMON_SH'
        _recompose_ignore
        cat \$GIT_PROJECT_ROOT/.git/personal/ignore
    "
    [ $status -eq 0 ]
    [[ "$output" =~ "Global patterns" ]]
    [[ "$output" =~ "Project patterns" ]]
}

@test "common: _recompose_ignore writes to correct location" {
    mkdir -p "$GIT_PROJECT_ROOT/.git/personal"
    cat > "$GIT_PROJECT_ROOT/.git/personal/project-ignore" <<'EOF'
*.swp
EOF
    
    cd "$GIT_PROJECT_ROOT"
    run bash -c "
        export GIT_PROJECT_ROOT='$GIT_PROJECT_ROOT'
        export GIT_WORKSPACE_ROOT='$GIT_WORKSPACE_ROOT'
        source '$COMMON_SH'
        _recompose_ignore
        [[ -f \$GIT_PROJECT_ROOT/.git/personal/ignore ]] && echo 'found'
    "
    [ $status -eq 0 ]
    [[ "$output" =~ "found" ]]
}

@test "common: _recompose_ignore returns success (0)" {
    mkdir -p "$GIT_PROJECT_ROOT/.git/personal"
    
    cd "$GIT_PROJECT_ROOT"
    run bash -c "
        export GIT_PROJECT_ROOT='$GIT_PROJECT_ROOT'
        export GIT_WORKSPACE_ROOT='$GIT_WORKSPACE_ROOT'
        source '$COMMON_SH'
        _recompose_ignore
    "
    [ $status -eq 0 ]
}

@test "common: _init_personal_dir creates .git/personal directory" {
    rm -rf "$GIT_PROJECT_ROOT/.git/personal"
    
    cd "$GIT_PROJECT_ROOT"
    run bash -c "
        export GIT_PROJECT_ROOT='$GIT_PROJECT_ROOT'
        source '$COMMON_SH'
        _init_personal_dir
        [[ -d \$GIT_PROJECT_ROOT/.git/personal ]] && echo 'created'
    "
    [ $status -eq 0 ]
    [[ "$output" == "created" ]]
}

@test "common: _init_personal_dir creates project-ignore stub" {
    rm -rf "$GIT_PROJECT_ROOT/.git/personal"
    
    cd "$GIT_PROJECT_ROOT"
    run bash -c "
        export GIT_PROJECT_ROOT='$GIT_PROJECT_ROOT'
        source '$COMMON_SH'
        _init_personal_dir
        [[ -f \$GIT_PROJECT_ROOT/.git/personal/project-ignore ]] && echo 'created'
    "
    [ $status -eq 0 ]
    [[ "$output" == "created" ]]
}

@test "common: _init_personal_dir handles existing directory" {
    mkdir -p "$GIT_PROJECT_ROOT/.git/personal"
    touch "$GIT_PROJECT_ROOT/.git/personal/project-ignore"
    
    cd "$GIT_PROJECT_ROOT"
    run bash -c "
        export GIT_PROJECT_ROOT='$GIT_PROJECT_ROOT'
        source '$COMMON_SH'
        _init_personal_dir
        echo 'success'
    "
    [ $status -eq 0 ]
    [[ "$output" == "success" ]]
}

@test "common: _init_personal_dir returns success (0)" {
    rm -rf "$GIT_PROJECT_ROOT/.git/personal"
    
    cd "$GIT_PROJECT_ROOT"
    run bash -c "
        export GIT_PROJECT_ROOT='$GIT_PROJECT_ROOT'
        source '$COMMON_SH'
        _init_personal_dir
    "
    [ $status -eq 0 ]
}

# ============================================================================
# Integration tests
# ============================================================================

@test "common: all functions work together in sequence" {
    mkdir -p "$HOME/.config/git-cloak"
    echo "*.log" > "$HOME/.config/git-cloak/ignore"
    
    mkdir -p "$GIT_WORKSPACE_ROOT/.git-cloak"
    echo "*.tmp" > "$GIT_WORKSPACE_ROOT/.git-cloak/ignore"
    
    mkdir -p "$GIT_PROJECT_ROOT/.git/personal"
    echo "*.swp" > "$GIT_PROJECT_ROOT/.git/personal/project-ignore"
    
    cd "$GIT_PROJECT_ROOT"
    run bash -c "
        export GIT_PROJECT_ROOT='$GIT_PROJECT_ROOT'
        export GIT_WORKSPACE_ROOT='$GIT_WORKSPACE_ROOT'
        source '$COMMON_SH'
        _resolve_project_root
        _resolve_workspace_root
        _init_personal_dir
        _recompose_ignore
        cat \$GIT_PROJECT_ROOT/.git/personal/ignore
    "
    [ $status -eq 0 ]
    [[ "$output" =~ "*.log" ]]
    [[ "$output" =~ "*.tmp" ]]
    [[ "$output" =~ "*.swp" ]]
}

@test "common: environment variables exported after resolution" {
    cd "$TEST_PROJECT"
    run bash -c "
        export GIT_PROJECT_ROOT='$GIT_PROJECT_ROOT'
        export GIT_WORKSPACE_ROOT='$GIT_WORKSPACE_ROOT'
        source '$COMMON_SH'
        _resolve_project_root
        _resolve_workspace_root
        echo \$GIT_PROJECT_ROOT:\$GIT_WORKSPACE_ROOT
    "
    [ $status -eq 0 ]
    [[ "$output" =~ "$TEST_PROJECT" ]]
    [[ "$output" =~ "$TEST_WORKSPACE" ]]
}
