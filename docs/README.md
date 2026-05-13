# git-shelf

> Personal file overlay manager for git — carry your changes across branches without a dedicated branch.

Shelf specific files at your personal version and carry them transparently across branch switches — no wrapper commands required.

## What it does

- **Persistent personal overlay** — shelved files survive `git switch`, `git pull`, and `git merge` via git hooks
- **Git-native storage** — personal versions stored as git blob objects in `.git/objects/`
- **Conflict-aware** — Bubbletea TUI prompts you when upstream diverges from your shelved version
- **Promote to PR** — eject your shelf to a real branch when you're ready to share

## Installation

```bash
brew tap jwill824/homebrew-tap
brew install git-shelf
```

See [HOMEBREW.md](HOMEBREW.md) for full distribution details.

## Quick start

```bash
cd my-repo
git shelf init              # install hooks once per repo

# Shelf a file at your personal version
echo "local: true" > config.yml
git shelf add config.yml    # snapshots your version as a git blob

# Use git normally — hooks restore your version automatically
git switch feature-branch   # config.yml stays at your version
git pull                    # same
git merge main              # same; prompts if upstream changed config.yml

# See what's shelved
git shelf list

# When ready to share
git shelf promote my-changes  # creates branch + commits your version
gh pr create                  # or: it'll offer to do this for you
```

## Commands

| Command | Description |
|---|---|
| `git shelf init` | Install hooks, initialize `.git/personal/` |
| `git shelf add <file>` | Shelf a file (tracked or untracked) |
| `git shelf remove <file>` | Un-shelf, restore repo version |
| `git shelf list` | Show shelved files + sync status |
| `git shelf diff [file]` | Diff personal vs repo version |
| `git shelf sync` | Re-apply all shelved files (recovery) |
| `git shelf promote <branch>` | Promote shelf to a real branch |

## How it works

1. `git shelf add config.yml` runs `git hash-object -w` to store your version as a blob, records the repo's current blob SHA as the "base", and sets skip-worktree on the file.
2. `git shelf init` installs `post-checkout`, `post-merge`, and `post-rewrite` hooks that call `git-shelf hook` after native git operations.
3. On branch switch, the hook compares each shelved file's current index blob to the stored base. If unchanged, it restores your personal blob silently. If upstream diverged, it opens an interactive TUI.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
