# git-cloak Design

**Date:** 2026-04-30

## Problem

When working in a shared git repository you often have local file changes (config overrides, personal tooling tweaks, env-specific values) that you want to keep in your worktree indefinitely without committing them. Git's `skip-worktree` flag and scoped ignore files solve this, but using them safely across branch switches, pulls, and merges requires careful orchestration. This tool makes that orchestration automatic, installable, and ergonomic.

---

## Core Concepts

### Two hiding mechanisms

| Mechanism | What it hides | Git command |
|---|---|---|
| `skip-worktree` | **Tracked** files — your local version is frozen, git stops seeing changes | `git update-index --skip-worktree` |
| Scoped ignore | **Untracked** files — personal files that git never sees at all | `core.excludesFile` |

### Three config scopes

| Scope | Config location | Applies to |
|---|---|---|
| **global** | `~/.config/git-cloak/ignore` | All repos on the machine |
| **workspace** | `<workspace>/.git-cloak/ignore` | All repos under a non-git workspace dir |
| **project** | `<repo>/.git/personal/ignore` | A single git repo |

Git's excludesFile chain: global → workspace → project (all layers are active simultaneously via separate `core.excludesFile` entries).

Skip-worktree state is always **project-scoped** — it lives in the git index.

---

## Repository Structure

```
git-cloak/
├── bin/
│   └── git-cloak              # dispatcher + $0-routing entry point
├── lib/
│   ├── common.sh              # path resolution, shared helpers
│   ├── cmd-init.sh
│   ├── cmd-hide.sh
│   ├── cmd-watch.sh
│   ├── cmd-unwatch.sh
│   ├── cmd-list.sh
│   ├── cmd-co.sh
│   ├── cmd-refresh.sh
│   ├── cmd-merge-main.sh
│   ├── cmd-sync.sh
│   └── cmd-monitor.sh
├── Formula/
│   └── git-cloak.rb           # Homebrew formula
├── docs/
│   └── superpowers/specs/
│       └── 2026-04-30-git-cloak-design.md
├── .envrc.example
└── README.md
```

---

## Installation Modes

### Homebrew (recommended, global)

```bash
brew tap <user>/tap
brew install git-cloak
```

Homebrew installs `bin/git-cloak` and creates symlinks for each alias command (`git-hide`, `git-watch`, `git-unwatch`, `git-co`, `git-refresh`, `git-merge-main`, `git-sync`, `git-monitor`). All commands are available in every terminal session.

### Local workspace install (direnv)

Clone git-cloak into a workspace directory and add to the workspace `.envrc`:

```bash
PATH_add bin   # adds git-cloak/bin to PATH when direnv loads this workspace
```

Commands are only active when direnv has loaded that workspace — useful for isolated environments or testing local changes to the tools themselves.

---

## Dispatcher + `$0` Routing

`bin/git-cloak` is the single entry point. Alias commands (e.g. `git-hide`, `git-watch`) are **symlinks pointing to `git-cloak`**. The script detects whether it was invoked as an alias (via `$0`) or as the primary dispatcher (via `$1`):

```zsh
#!/usr/bin/env zsh
_self="${${0:t}#git-}"          # strip "git-" prefix: "git-hide" → "hide"

if [[ "$_self" == "cloak" ]]; then
  _cmd="$1"; shift              # dispatched as: git cloak <cmd> [args]
else
  _cmd="$_self"                 # invoked as alias: git-hide [args]
fi

_LIB="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/../lib"
source "$_LIB/common.sh"

case "$_cmd" in
  init)        source "$_LIB/cmd-init.sh" ;;
  hide)        source "$_LIB/cmd-hide.sh" ;;
  watch)       source "$_LIB/cmd-watch.sh" ;;
  unwatch)     source "$_LIB/cmd-unwatch.sh" ;;
  list)        source "$_LIB/cmd-list.sh" ;;
  co)          source "$_LIB/cmd-co.sh" ;;
  refresh)     source "$_LIB/cmd-refresh.sh" ;;
  merge-main)  source "$_LIB/cmd-merge-main.sh" ;;
  sync)        source "$_LIB/cmd-sync.sh" ;;
  monitor)     source "$_LIB/cmd-monitor.sh" ;;
  *)           echo "Usage: git cloak <command> [args]"
               echo "Commands: init, hide, watch, unwatch, list, co, refresh, merge-main, sync, monitor"
               exit 1 ;;
esac
```

Both `git cloak hide <pattern>` and `git hide <pattern>` call the same logic.

---

## Path Resolution (`common.sh`)

```zsh
# 1. Find the target git repo root
if [[ -n "$GIT_PROJECT_ROOT" ]]; then
  _PROJECT_DIR="$GIT_PROJECT_ROOT"
else
  _PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [[ -z "$_PROJECT_DIR" ]]; then
    echo "Error: not inside a git repository. Run 'git cloak init' first."
    exit 1
  fi
fi

# 2. Find the workspace root (non-git ancestor with .envrc or .git-cloak/)
_WORKSPACE_DIR=""
_dir="$(dirname "$_PROJECT_DIR")"
while [[ "$_dir" != "/" ]]; do
  if [[ -f "$_dir/.envrc" || -d "$_dir/.git-cloak" ]]; then
    _WORKSPACE_DIR="$_dir"
    break
  fi
  _dir="$(dirname "$_dir")"
done

# 3. Resolve personal config dirs
_PROJECT_PERSONAL_DIR="$(git -C "$_PROJECT_DIR" rev-parse --git-dir)/personal"
_WORKSPACE_CLOAK_DIR="${_WORKSPACE_DIR:+$_WORKSPACE_DIR/.git-cloak}"
_GLOBAL_CLOAK_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/git-cloak"
```

`GIT_PROJECT_ROOT` is only needed when running commands from a workspace directory that is not itself a git repo (e.g. `cd jumpmind && git cloak list`). When already inside a git repo, it is auto-detected and `GIT_PROJECT_ROOT` is ignored.

---

## `git cloak init`

Interactive setup. Detects context and configures the appropriate scopes.

### In a git repo (project scope)
```bash
git cloak init
```
- Creates `.git/personal/` directory
- Sets `core.excludesFile` to `.git/personal/ignore` in the repo's local git config
- Optionally installs git hooks (see below)

### In a workspace root (workspace scope)
```bash
git cloak init --workspace
```
- Creates `.git-cloak/` directory in the workspace
- Checks for an existing `.envrc`; if present, appends `GIT_PROJECT_ROOT` if not already set
- Prompts user to run `direnv allow` if `.envrc` was modified
- When a repo under the workspace is later initialized, its `core.excludesFile` is set to point to the workspace `.git-cloak/ignore`

### Global
```bash
git cloak init --global
```
- Creates `~/.config/git-cloak/` directory
- Sets git's global `core.excludesFile` to `~/.config/git-cloak/ignore`

---

## `git hide` — Scoped Ignore Patterns

Adds a pattern to the appropriate scope's ignore file.

```bash
git hide "*.local-backup"            # auto-detect scope (workspace if present, else project)
git hide --project ".env.local"      # project scope only
git hide --workspace "*.local-backup"# workspace scope
git hide --global ".DS_Store"        # global scope
```

On first use, if `core.excludesFile` is not yet configured for the target scope, the command configures it automatically.

---

## `git watch` / `git unwatch` — Skip-Worktree

Always project-scoped (skip-worktree is a git index concept).

```bash
git watch path/to/file.yml       # mark file as skip-worktree
git unwatch path/to/file.yml     # remove skip-worktree
git list                          # show all skip-worktree files + active ignore patterns
```

---

## Safe Branch Operations

`git cloak co`, `git cloak refresh`, and `git cloak merge-main` all share the same lifecycle to safely handle skip-worktree files:

1. Collect all skip-worktree files
2. Clear `skip-worktree` on all of them (so git can operate freely)
3. Stash local changes
4. Perform the git operation (checkout / pull / merge)
5. Pop the stash
6. For conflicts:
   - Files in the **monitor list** → pause, show diff, require manual resolution
   - All other files → auto-resolve (keep local version)
7. Re-apply `skip-worktree` to all files
8. Unstage everything

```bash
git cloak co <branch>         # safe branch switch
git cloak refresh             # safe pull on current branch
git cloak merge-main          # safe merge of origin/main into current branch
```

After manually resolving a monitored-file conflict:
```bash
git cloak co --restore-watch
git cloak refresh --restore-watch
git cloak merge-main --restore-watch
```

---

## Git Hooks (Optional)

`git cloak init --hooks` installs lightweight hooks into `.git/hooks/` as a safety net for users who run native git commands directly. These hooks only handle the **re-apply** step (post-operation); they do not perform the stash dance (no `pre-checkout` hook exists in git).

| Hook | Trigger | Action |
|---|---|---|
| `post-checkout` | `git checkout` | Re-apply skip-worktree |
| `post-merge` | `git pull` / `git merge` | Re-apply skip-worktree |
| `post-rewrite` | `git rebase` / `git commit --amend` | Re-apply skip-worktree |

**Important:** These hooks provide a safety net, not full protection. The safe stash dance (which prevents conflicts during the operation) is only available via the `git cloak` commands. Users who want full safety should use `git cloak co` / `git cloak refresh` / `git cloak merge-main`.

---

## `git monitor` — Conflict Watch List

Manages the per-project list of files that trigger a manual review pause during branch operations (instead of auto-resolving in your favor).

```bash
git monitor add path/to/file.yml
git monitor remove path/to/file.yml
git monitor list
```

Watch list is stored at `.git/personal/watch-list`.

---

## `git sync` — Pull Upstream for a Skip-Worktree File

When a skip-worktree file has upstream changes you want to review and merge into your local version:

```bash
git sync path/to/file.yml
```

Saves your local version as `<file>.local-backup`, fetches the upstream version, shows a diff, and re-applies skip-worktree.

---

## `.envrc` Integration

`git cloak init --workspace` appends to an existing `.envrc` (or creates one):

```bash
# git-cloak workspace config
export GIT_PROJECT_ROOT="$PWD/commerce"
```

`GIT_PERSONAL_DIR` is not written to `.envrc` — personal config is always discovered automatically (workspace `.git-cloak/` or project `.git/personal/`).

`.envrc.example` ships with the repo as a reference template.

---

## Homebrew Formula

The formula lives in `Formula/git-cloak.rb` in this repo. A separate `homebrew-tap` repo references it via GitHub release tarballs.

```ruby
class GitCloak < Formula
  desc "Personal file overlay manager for git — hide local changes, stay in sync"
  homepage "https://github.com/<user>/git-cloak"
  # url and sha256 filled in at release time

  def install
    bin.install "bin/git-cloak"
    (lib/"git-cloak").install Dir["lib/*.sh"]

    %w[hide watch unwatch list co refresh merge-main sync monitor].each do |cmd|
      bin.install_symlink "git-cloak" => "git-#{cmd}"
    end
  end

  def caveats
    <<~EOS
      Run 'git cloak init' inside any repo to get started.
      For workspace setups, run 'git cloak init --workspace' from the workspace root.
    EOS
  end
end
```

---

## Migration from Existing jumpmind Setup

1. Install git-cloak via Homebrew (or local workspace install)
2. Remove `bin/` from `~/Developer/jumpmind` (scripts now come from Homebrew)
3. Run `git cloak init --workspace` from `~/Developer/jumpmind` — it detects the existing `.envrc` and `.gitignore`, migrates patterns to `.git-cloak/ignore`, and configures `GIT_PROJECT_ROOT`
4. Run `git cloak init` from `~/Developer/jumpmind/commerce` — wires up `core.excludesFile` to the workspace ignore file
5. Existing skip-worktree state in the `commerce` index is untouched — no re-setup needed
