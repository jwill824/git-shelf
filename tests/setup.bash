# tests/setup.bash
# Shared setup/teardown for all bats test files.
# Load in each test file with:  load 'setup'

setup() {
  # Isolate from the real global git config and HOME
  export ORIG_HOME="$HOME"
  export HOME
  HOME="$(mktemp -d)"
  export XDG_CONFIG_HOME="$HOME/.config"

  # Minimal git identity (required for commits)
  git config --global user.name "Test User"
  git config --global user.email "test@example.com"
  git config --global init.defaultBranch main

  # Locate the git-cloak binary relative to tests/
  export GIT_CLOAK
  GIT_CLOAK="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bin/git-cloak"

  # Create a bare "remote" so push/pull tests work
  export TEST_REMOTE
  TEST_REMOTE="$(mktemp -d)/remote.git"
  git init --bare "$TEST_REMOTE"

  # Clone bare repo as our working copy
  export TEST_REPO
  TEST_REPO="$(mktemp -d)/myrepo"
  git clone "$TEST_REMOTE" "$TEST_REPO" 2>/dev/null

  # Initial tracked file + push to origin/main
  cd "$TEST_REPO"
  echo "# Test Repo" > README.md
  git add README.md
  git commit -m "Initial commit"
  git push -u origin main 2>/dev/null
}

teardown() {
  cd / 2>/dev/null || true
  rm -rf "$HOME" "$(dirname "$TEST_REMOTE")" "$(dirname "$TEST_REPO")"
  export HOME="$ORIG_HOME"
}
