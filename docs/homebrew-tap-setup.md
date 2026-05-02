# Homebrew Tap Setup

This document explains how to set up and use the Homebrew distribution for git-cloak.

## Overview

git-cloak uses a **Homebrew tap** for distribution. A tap is a Git repository containing Homebrew formulas.

- **Tap repository:** `jwill824/homebrew-tap` (separate repo)
- **Install command:** `brew tap jwill824/homebrew-tap && brew install git-cloak`
- **Updates:** Automatic when you push releases to main branch

## Setup Instructions

### 1. Create the Tap Repository

Create a new GitHub repository named `homebrew-tap` under your account (thingstead):

```bash
# On GitHub, create a new repo: jwill824/homebrew-tap

# Clone it locally
git clone https://github.com/jwill824/homebrew-tap.git
cd homebrew-tap

# Create the Formula directory
mkdir -p Formula

# Copy the formula template (we'll auto-populate this)
echo "# Formula will be auto-updated by release workflow" > Formula/git-cloak.rb

git add Formula/
git commit -m "Initial commit: set up tap repository"
git push origin main
```

### 2. Create GitHub Personal Access Token

The release workflow needs permission to push to the tap repository:

1. Go to GitHub Settings → Developer Settings → Personal Access Tokens
2. Create a new token with scopes:
   - `repo` (full control of private repositories)
   - `workflow` (update GitHub Action workflows)
3. Copy the token

### 3. Add Token to git-cloak Repository Secrets

1. Go to git-cloak repository → Settings → Secrets and variables → Actions
2. Create new repository secret: `HOMEBREW_TAP_TOKEN`
3. Paste the personal access token

### 4. Verify Release Workflow

The release workflow now:

1. **On each release to main:**
   - Detects the new version (via semantic-release)
   - Downloads the release tarball
   - Calculates SHA256 checksum
   - Updates `Formula/git-cloak.rb` in the tap repo with:
     - New version number
     - New tarball URL
     - New SHA256
   - Commits and pushes to `jwill824/homebrew-tap`

2. **Installation for users:**
   ```bash
   brew tap jwill824/homebrew-tap
   brew install git-cloak
   
   # Update to latest
   brew update
   brew upgrade git-cloak
   ```

## Example Release Flow

```bash
# In git-cloak repo, commit a new feature
git commit -m "feat: add new command"
git push origin main

# GitHub Actions:
# 1. Tests pass ✓
# 2. Linter passes ✓
# 3. Release workflow triggers:
#    - semantic-release detects "feat" → bumps minor version
#    - Creates v0.2.0 release
#    - Updates Formula/git-cloak.rb with v0.2.0 + SHA256
#    - Pushes to jwill824/homebrew-tap
#
# Users can now:
# brew tap jwill824/homebrew-tap
# brew install git-cloak  # Gets v0.2.0
```

## Manual Formula Updates (if needed)

If the automatic update fails, you can manually update `Formula/git-cloak.rb`:

```ruby
class GitCloak < Formula
  desc "Personal file overlay manager for git — hide local changes, stay in sync"
  homepage "https://github.com/jwill824/git-cloak"
  url "https://github.com/jwill824/git-cloak/archive/refs/tags/vX.Y.Z.tar.gz"
  sha256 "<paste-sha256-here>"
  license "MIT"

  def install
    bin.install "bin/git-cloak"
    (lib/"git-cloak").install Dir["lib/*.sh"]
  end

  def caveats
    <<~EOS
      Run 'git cloak init' inside any repo to get started.
      For workspace setups, run 'git cloak init --workspace' from the workspace root first.
      For global setup, run 'git cloak init --global'.
    EOS
  end

  test do
    system "#{bin}/git-cloak", "--help"
  end
end
```

To get SHA256:
```bash
VERSION="0.2.0"
curl -sL https://github.com/jwill824/git-cloak/archive/refs/tags/v${VERSION}.tar.gz | shasum -a 256
```

## Troubleshooting

**"Error: Failed to clone the tap repository"**
- Verify `HOMEBREW_TAP_TOKEN` is set in git-cloak repo secrets
- Token must have `repo` scope

**"SHA256 mismatch when installing"**
- Manually recalculate and update the formula (see above)
- Re-commit to the tap

**"Tap not found when users install"**
- Ensure `jwill824/homebrew-tap` is public on GitHub
- Test locally: `brew tap jwill824/homebrew-tap`

## Resources

- [Homebrew Tap Documentation](https://docs.brew.sh/Taps)
- [Creating Homebrew Formulas](https://docs.brew.sh/Formula-Cookbook)
- [Semantic Release Homebrew Integration](https://github.com/semantic-release/semantic-release)
