# git-cloak

Personal file overlay manager for git. Hide local changes to tracked files and personal untracked files safely across branch switches, pulls, and merges.

## What it does

Two hiding mechanisms:
- **skip-worktree** — git stops seeing your local changes to a tracked file
- **Scoped ignore** — personal untracked files that git never sees

Three config scopes:
- **global** — `~/.config/git-cloak/ignore` — applies to all repos on the machine
- **workspace** — `<workspace>/.git-cloak/ignore` — all repos under a workspace directory
- **project** — `.git/personal/project-ignore` — single repo only

## Installation

### Homebrew (recommended)
```bash
brew tap jumpmind/tap
brew install git-cloak
```

### Local workspace (direnv)
Clone into a workspace directory and add to `.envrc`:
```bash
PATH_add /path/to/git-cloak/bin
```

### Manual
Clone and add to your PATH:
```bash
git clone https://github.com/jumpmind/git-cloak ~/Developer/tools/git-cloak
export PATH="$HOME/Developer/tools/git-cloak/bin:$PATH"
```

## Quick start

### Initialize a repository
```bash
cd my-repo
git cloak init
```

### Hide a file you've locally modified
Hide `config.yml` from git while keeping your local changes:
```bash
git cloak hide config.yml
```

This:
1. Marks the file skip-worktree (git stops tracking changes)
2. Adds it to project-ignore so git never sees it even if you unstash
3. Your local changes are safe; pulling/merging won't overwrite them

### Safe branch operations
```bash
# Safe pull with skip-worktree files preserved
git cloak refresh

# Safe merge main with skip-worktree files preserved
git cloak merge-main

# Safe branch switch with skip-worktree files preserved
git cloak switch feature-branch
```

All operations:
1. Collect which files have skip-worktree set
2. Clear skip-worktree to prevent conflicts
3. Perform the git operation (pull, merge, switch)
4. Re-apply skip-worktree flags
5. Report success

### Watch files for manual conflict handling
For files that might have real conflicts during branch ops, add them to the watch-list:
```bash
git cloak monitor add config.yml
git cloak monitor list
git cloak monitor remove config.yml
```

Watched files pause operations and prompt for manual resolution.

### Sync skip-worktree flags
If files get out of sync, resync from project-ignore:
```bash
git cloak sync
```

## Commands

```bash
git cloak init                 # Initialize repo (.git/personal, config)
git cloak hide <file>         # Mark file skip-worktree + add to ignore
git cloak list                # Show all hidden files
git cloak watch <file>        # Add file to conflict watch-list
git cloak unwatch <file>      # Remove file from watch-list
git cloak monitor add <file>  # Alias for watch
git cloak monitor remove <file> # Alias for unwatch
git cloak monitor list        # Show watched files
git cloak refresh             # Safe git pull with skip-worktree
git cloak merge-main          # Safe merge main with skip-worktree
git cloak sync                # Re-sync skip-worktree from project-ignore
git cloak switch <branch>     # Safe branch switch with skip-worktree
```

## Config scopes

### Global config
`~/.config/git-cloak/ignore` — applies to all repos

```bash
# Example: always ignore .env and node_modules on this machine
echo ".env" >> ~/.config/git-cloak/ignore
echo "node_modules" >> ~/.config/git-cloak/ignore
```

### Workspace config
`<workspace>/.git-cloak/ignore` — applies to all repos under the workspace

Initialize the workspace:
```bash
cd ~/Developer
mkdir .git-cloak
echo "config.yml" > .git-cloak/ignore
```

Then in any repo under `~/Developer`:
```bash
cd ~/Developer/my-repo
git cloak init  # uses workspace config too
```

### Project config
`.git/personal/project-ignore` — single repo only

Created automatically by `git cloak init`. Edit directly or use `git cloak hide`.

## Use cases

### Local overrides
You have a `config.yml` that differs locally but is tracked in git.
```bash
git cloak hide config.yml
# Now git never sees your changes, pull/merge/switch work safely
```

### Development tooling
You have a local build script or secrets file in `.gitignore` but want to keep working tree clean across branches.
```bash
git cloak hide Makefile.local
git cloak hide .env.local
```

### Experimental files
You're testing code that shouldn't be committed yet but want to switch branches without losing it.
```bash
git cloak hide experimental-feature.js
# Keep testing, safe branch switches with content preserved
```

### Workspace setup
Team with unified workspace structure but per-machine overrides.
```bash
# In workspace root
echo "local.config" > .git-cloak/ignore
echo "build/artifacts/*" >> .git-cloak/ignore

# Then in any repo under the workspace
git cloak init  # respects workspace rules
```

## How it works internally

### Path resolution
1. When you run `git cloak` in a repo, it finds the repo root with `git rev-parse --show-toplevel`
2. It optionally walks up to find a workspace marker (`.git-cloak/` directory)
3. It checks three locations for ignore files (global, workspace, project) in order of specificity

### Ignore composition
The ignore file at `.git/personal/ignore` is a composite of three scopes:
- Comments from global/workspace/project files are preserved
- Files from all three scopes are merged
- git is configured to use this as `core.excludesFile`

### Skip-worktree lifecycle
Safe operations (refresh, merge-main, switch) follow this pattern:
1. **Collect** — list all files with skip-worktree flag set
2. **Clear** — remove all skip-worktree flags (prevents conflicts)
3. **Operate** — perform git operation (pull, merge, switch)
4. **Pop** — pop stash if changes were stashed
5. **Reapply** — set skip-worktree flags back on the same files

This prevents git from trying to merge changes to skip-worktree files.

## Troubleshooting

**I ran `git pull` directly and it broke skip-worktree**
```bash
git cloak sync  # re-apply skip-worktree flags from project-ignore
```

**A file's real conflict needs manual resolution**
```bash
git cloak monitor add config.yml     # add to watch-list
git cloak switch my-branch           # will pause and ask for manual resolution
# ... resolve conflicts, git add, then:
git cloak switch --restore-watch     # re-apply skip-worktree after resolving
```

**I see "Not in a git repository"**
```bash
# Make sure you're in a directory that's inside a git repo
cd /path/to/my-repo
git cloak init
```

## License

MIT
