# GitHub Actions Workflows

git-cloak includes three automated workflows for continuous integration and release management.

## 1. Test Workflow (.github/workflows/test.yml)

**Trigger:** On push to main, on pull requests

**Actions:**
- Installs bats-core (BATS test framework)
- Runs `make test` (all 120+ tests)
- Reports results

**Matrix:** macOS latest (zsh environment)

**Status badge:**
```markdown
[![Tests](https://github.com/<org>/git-cloak/actions/workflows/test.yml/badge.svg)](https://github.com/<org>/git-cloak/actions/workflows/test.yml)
```

## 2. Lint Workflow (.github/workflows/lint.yml)

**Trigger:** On push to main, on pull requests

**Actions:**
- Runs `shellcheck` on all .sh files (bin/git-cloak, lib/*.sh)
- Validates script permissions (executable bits)

**Status badge:**
```markdown
[![Lint](https://github.com/<org>/git-cloak/actions/workflows/lint.yml/badge.svg)](https://github.com/<org>/git-cloak/actions/workflows/lint.yml)
```

## 3. Release Workflow (.github/workflows/release.yml)

**Trigger:** On push to main (automated releases only)

**Actions:**
- Analyzes commit messages (Conventional Commits)
- Determines version bump (major/minor/patch)
- Updates CHANGELOG.md
- Creates GitHub Release with release notes
- Tags the commit with version

**Version Rules (.releaserc.json):**
- `feat:` → minor version bump (v0.1.0 → v0.2.0)
- `fix:` → patch version bump (v0.1.0 → v0.1.1)
- `docs:` → patch version bump
- `perf:` → patch version bump
- `refactor:` → patch version bump
- `test:` → no version bump
- `chore:` → no version bump

**Commit Message Format:**

```bash
# Minor version bump
git commit -m "feat: add new command git cloak foobar"

# Patch version bump
git commit -m "fix: handle edge case in skip-worktree"

# No version bump
git commit -m "test: add integration test for switch command"

# Breaking change (major version bump)
git commit -m "feat!: redesign config file format"
```

## Usage

### Running Tests Locally
```bash
make test
```

### Running Linter Locally
```bash
shellcheck bin/git-cloak lib/*.sh
```

### Creating a Release
Just push a commit with a conventional commit message to main:
```bash
git commit -m "feat: add new feature"
git push origin main
```

GitHub Actions will:
1. Detect the commit type
2. Calculate next version
3. Create a GitHub Release
4. Update CHANGELOG.md
5. Tag the commit

### Viewing Releases
```bash
# View all releases on GitHub
open https://github.com/<org>/git-cloak/releases

# Or get latest version tag locally after push
git fetch --tags
git describe --tags
```

## Troubleshooting

**Tests fail:**
- Check workflow logs: Actions tab on GitHub
- Run locally: `make test`
- Ensure zsh is available (macOS)

**Linter fails:**
- Run locally: `shellcheck bin/git-cloak lib/*.sh`
- Fix issues and recommit

**Release doesn't trigger:**
- Check that commits use Conventional Commits format
- Ensure commits are pushed to main
- Verify .releaserc.json is committed

**Release bumps wrong version:**
- Check commit message format (feat/fix/docs/etc.)
- Verify .releaserc.json release rules match intent
