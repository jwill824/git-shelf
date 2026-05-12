# git-shelf Design Spec
**Date:** 2026-05-11  
**Status:** Approved  
**Replaces:** git-cloak

---

## Problem & Approach

Developers working in repos they don't own (open source, client projects) often have personal file modifications — local config overrides, tooling tweaks, environment-specific changes — that they need to carry across branches without polluting any branch or being forced to stay on a personal branch.

git-shelf is a git extension that maintains a **personal file overlay** that travels with you across branch switches. Specific files are "shelved" at your personal version and survive any git branch operation transparently. When you're ready to share changes, you can promote the shelf to a real branch and open a PR.

The tool is built on git's native object store (blobs), uses git hooks for transparent integration with native git commands, and provides a Bubbletea TUI for conflict resolution.

---

## Core Mental Model

```
shelf = personal scratchpad, travels across branches, invisible to team
  ↓  git shelf promote <branch>
branch = shareable, PR-able, normal git contribution
```

You never have to remember to use wrapper commands. Native `git switch`, `git pull`, and `git merge` all trigger the shelf hooks automatically.

---

## Architecture

### Storage

```
.git/
  objects/              ← personal blobs live here (native git storage)
  personal/
    shelf-index         ← one line per shelved file
  hooks/
    post-checkout       ← fires after git switch, git checkout (branch changes only)
    post-merge          ← fires after git merge, git pull
    post-rewrite        ← fires after git rebase, git commit --amend
```

**shelf-index format** (tab-separated):
```
config.yml    <personal_blob>    <base_blob>    tracked
.env.local    <personal_blob>                   untracked
```

- `personal_blob`: SHA of your version, stored as a git blob object
- `base_blob`: SHA of the repo's version at time of shelving (empty for untracked files)
- Type: `tracked` (file exists in git index) or `untracked` (personal-only file)

### Why git blobs

- Git already stores file content this way internally — no custom format
- Deduplication is free (same content = same SHA)
- `git diff <blob1> <blob2>` works natively — no custom diff logic
- Blobs persist in `.git/objects/` independently of any branch or index state
- `git hash-object -w` and `git cat-file blob` are stable plumbing commands

### Skip-worktree

Skip-worktree flags on tracked files prevent git from overwriting them during index operations. The hooks handle re-applying these flags after any branch operation.

---

## Commands

```bash
# Setup
git shelf init                    # install hooks, create .git/personal/

# Managing the shelf
git shelf add <file>              # shelf a file (tracked or untracked)
git shelf remove <file>           # un-shelf: remove skip-worktree, restore HEAD version (tracked) or delete (untracked)
git shelf list                    # show shelved files + sync status
git shelf diff [file]             # diff personal version vs repo version
git shelf sync                    # re-apply all shelved files (recovery)

# Promote to branch
git shelf promote <branch-name>   # eject shelf to a real git branch (PR-ready)
```

Wrapper commands (`git shelf switch`, `git shelf pull`) exist as opt-in pre-flight safety — they warn before a conflicting operation rather than resolving after. The hooks handle the common path.

---

## Data Flow

### `git shelf add <file>`

1. Read file from working tree
2. `git hash-object -w <file>` → personal blob SHA
3. For tracked files: `git ls-files -s <file>` → base blob SHA
4. For untracked files: base blob = `""` (no repo version exists)
5. Append to `shelf-index`
6. For tracked files: `git update-index --skip-worktree <file>`

### Hook lifecycle (e.g., native `git switch feature-branch`)

1. Git performs the branch switch normally
2. `post-checkout` fires → git-shelf reads `shelf-index`
3. For each shelved file, get the new branch's blob: `git ls-files -s <file>`
4. Conflict detection:
   - `new_blob == base_blob` → upstream unchanged → restore personal blob silently
   - `new_blob == personal_blob` → already correct → no-op  
   - `new_blob == ""` (file removed on new branch) → restore personal blob as untracked
   - `new_blob != base_blob && new_blob != personal_blob` → **conflict** → TUI prompt
5. Restore: `git cat-file blob <personal_blob> > <file>`, re-apply skip-worktree

### `git shelf promote <branch-name>`

Promotes **all** shelved files. Use `git shelf remove <file>` first to exclude specific files.

1. Create new branch from current HEAD: `git checkout -b <branch-name>`
2. For each shelved file: `git cat-file blob <personal_blob> > <file>`
3. `git add <shelved-files...>`
4. `git commit -m "Personal shelf changes"`
5. Offer to push and open a PR via `gh pr create` (if `gh` is available)
6. Shelf is preserved — promotion does not remove the shelf

---

## Conflict Resolution TUI (Bubbletea)

Fires from the hook when upstream diverges from base blob:

```
⚠  Shelf conflict: config.yml

   Upstream changed this file while you had it shelved.

 ↑ Keep mine     restore my shelved version (default)
   Take theirs   update shelf to upstream version
   Show diff     view side-by-side diff
   Open editor   resolve manually, then re-shelf
```

- Arrow keys navigate, Enter confirms
- "Show diff" runs `git diff <personal_blob> <new_blob>` in a pager below the prompt
- "Open editor" writes both versions to temp files and invokes `$GIT_EDITOR` or `$EDITOR`; after the editor closes, git-shelf detects the saved file and offers to re-shelf it automatically
- If multiple files conflict, prompts run sequentially

---

## Project Structure

```
git-shelf/
  cmd/
    git-shelf/
      main.go             ← entry point, cobra command routing
  internal/
    shelf/
      index.go            ← shelf-index read/write/parse
      blob.go             ← git hash-object, cat-file, ls-files wrappers
      skipworktree.go     ← skip-worktree flag management
      hooks.go            ← install/uninstall/invoke hooks
    tui/
      conflict.go         ← Bubbletea conflict resolution model
      status.go           ← Bubbletea shelf status view
    git/
      ops.go              ← branch creation, promote, gh integration
  Formula/
    git-shelf.rb          ← Homebrew formula (updated from git-cloak)
  docs/
    superpowers/
      specs/
        2026-05-11-git-shelf-design.md
```

### Key dependencies

- `github.com/spf13/cobra` — CLI command structure
- `github.com/charmbracelet/bubbletea` — TUI framework
- `github.com/charmbracelet/lipgloss` — TUI styling
- Standard library only for git plumbing (exec.Command wrapping git)

---

## Error Handling

- Hook failures must never leave the working tree in a broken state. Restore is always attempted; if it fails, a clear error is printed with a recovery command (`git shelf sync`).
- If `shelf-index` is corrupted or missing, commands fail fast with a clear message directing the user to `git shelf init`.
- Untracked personal files that conflict with a file added to the branch are flagged but not overwritten without confirmation.
- `git shelf sync` is the universal recovery command — re-reads index and re-applies all personal blobs.

---

## Testing Strategy

- Unit tests for `shelf/index.go` (parse/write round-trips), `shelf/blob.go` (hash-object/cat-file), and conflict detection logic
- Integration tests using `git init` in temp directories — real git operations, real hooks, real blob storage
- TUI tests via Bubbletea's test utilities (simulate key events, assert model state)
- No mocking of git — integration tests run against real git binary

---

## Migration from git-cloak

- Rename binary and Homebrew formula
- `git cloak init` → `git shelf init` (hooks replace the old ignore-file approach)
- `git cloak hide` → `git shelf add`
- `git cloak reveal` / `git cloak list` → `git shelf list`
- `git cloak sync` → `git shelf sync`
- `git cloak switch/pull/merge-main` → removed (hooks handle this natively)
- `git cloak monitor/watch/unwatch` → removed (all shelved files get conflict detection)
- Project-ignore and workspace-ignore scopes are removed; shelf is repo-scoped only
