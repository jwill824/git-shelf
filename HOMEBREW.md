# Homebrew Distribution Quick Start

## What's Set Up

The release workflow now **automatically updates** the Homebrew tap whenever you push a release.

## 3-Step Setup

### 1. Create the Tap Repository

```bash
# Create new GitHub repo: jwill824/homebrew-tap

git clone https://github.com/jwill824/homebrew-tap.git
cd homebrew-tap

mkdir -p Formula
git add Formula/
git commit -m "Initial commit"
git push origin main
```

### 2. Create GitHub Token

1. GitHub Settings → Developer Settings → Personal Access Tokens → Generate new token
2. Select scopes: `repo`, `workflow`
3. Copy the token

### 3. Add Secret to git-cloak

```bash
# Go to: git-cloak repo → Settings → Secrets and variables → Actions
# Create new secret: HOMEBREW_TAP_TOKEN
# Paste your token
```

## That's It! 🎉

Now when you push a release:

```bash
git commit -m "feat: add new command"
git push origin main
```

The workflow automatically:
1. ✅ Runs tests
2. ✅ Runs linter
3. ✅ Bumps version (semantic-release)
4. ✅ Creates GitHub release
5. ✅ **Updates jwill824/homebrew-tap with new formula**

## Users Install With

```bash
brew tap jwill824/homebrew-tap
brew install git-cloak

# Update later with
brew upgrade git-cloak
```

## What the Workflow Does

For each release, the workflow:
- Extracts the new version
- Downloads the release tarball
- Calculates SHA256
- Updates `Formula/git-cloak.rb` in the tap
- Commits: `chore(homebrew): bump git-cloak to vX.Y.Z`
- Pushes to `jwill824/homebrew-tap`

## Troubleshooting

**"Error: Failed to clone tap repository"**
→ Check HOMEBREW_TAP_TOKEN is set and has `repo` scope

**"SHA256 mismatch when installing"**
→ Manually update formula (see homebrew-tap-setup.md)

**Tests are still passing locally but not in CI**
→ Ensure bats-core is installed in test workflow

See `docs/homebrew-tap-setup.md` for full details.
