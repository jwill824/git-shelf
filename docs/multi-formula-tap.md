# Multi-Formula Homebrew Tap Setup

Yes! A single Homebrew tap repository can contain **multiple formulas**. This is ideal for a unified distribution point for all your tools.

## Structure

```
thingstead/homebrew-tap/
├── Formula/
│   ├── git-cloak.rb
│   ├── other-tool.rb
│   ├── another-tool.rb
│   └── ...
├── README.md
└── .github/
    └── workflows/
        └── test.yml  (optional: test formulas)
```

## User Experience

With multiple formulas in one tap:

```bash
# Install the tap once
brew tap thingstead/homebrew-tap

# Then users can install any formula from that tap
brew install git-cloak
brew install other-tool
brew install another-tool

# Update all tools at once
brew update
brew upgrade
```

## Adding Formulas to the Tap

### Manual: Create the formula file

```bash
cd thingstead/homebrew-tap
cat > Formula/my-new-tool.rb << 'EOF'
class MyNewTool < Formula
  desc "My awesome tool"
  homepage "https://github.com/thingstead/my-new-tool"
  url "https://github.com/thingstead/my-new-tool/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "abc123def456..."
  license "MIT"

  def install
    bin.install "bin/my-new-tool"
    # Add any other install steps
  end

  test do
    system "#{bin}/my-new-tool", "--version"
  end
end
EOF

git add Formula/my-new-tool.rb
git commit -m "Add my-new-tool formula"
git push origin main
```

### Automatic: Set up per-repo release workflows

Each repository (git-cloak, other-tool, etc.) can have its own release workflow that updates the shared tap:

**In each repo's `.github/workflows/release.yml`:**

```yaml
- name: Update Homebrew tap
  if: success()
  env:
    HOMEBREW_TAP_TOKEN: ${{ secrets.HOMEBREW_TAP_TOKEN }}
  run: |
    # Extract repo name and version
    REPO_NAME=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f2)
    VERSION=$(git describe --tags --abbrev=0 | sed 's/^v//')
    
    # Formula name (e.g., git-cloak → git-cloak.rb)
    FORMULA_NAME="${REPO_NAME//-/}"
    FORMULA_NAME="${FORMULA_NAME:0:1}$(echo ${FORMULA_NAME:1} | tr '[:upper:]' '[:lower:]')"
    
    # Calculate SHA256
    TARBALL_URL="https://github.com/thingstead/${REPO_NAME}/archive/refs/tags/v${VERSION}.tar.gz"
    SHA256=$(curl -sL "$TARBALL_URL" | shasum -a 256 | cut -d' ' -f1)
    
    # Clone and update
    git clone https://x-access-token:${HOMEBREW_TAP_TOKEN}@github.com/thingstead/homebrew-tap.git tap-repo
    cd tap-repo
    
    # Update or create the formula
    cat > Formula/${REPO_NAME}.rb << FORMULA
class $(echo ${REPO_NAME//-/} | awk '{for(i=1;i<=NF;i++)$i=toupper(substr($i,1,1)) tolower(substr($i,2))}1') < Formula
  # ... formula content ...
FORMULA
    
    git config user.name "Release Bot"
    git config user.email "bot@thingstead.com"
    git add Formula/
    git commit -m "chore: bump ${REPO_NAME} to v${VERSION}"
    git push
```

## Examples

### Example 1: Multiple independent projects

```bash
# Each repo maintains its own formula
git-cloak/        → updates Formula/git-cloak.rb
my-api-tool/      → updates Formula/my-api-tool.rb
my-cli-tool/      → updates Formula/my-cli-tool.rb
my-utils/         → updates Formula/my-utils.rb
```

Installation:
```bash
brew tap thingstead/homebrew-tap
brew install git-cloak my-api-tool my-cli-tool my-utils
```

### Example 2: Version-specific formulas

You could also have different versions or variants:

```bash
Formula/
├── git-cloak.rb           # Stable version
├── git-cloak@0.1.rb       # Legacy version (if needed)
└── git-cloak@edge.rb      # Development version (from HEAD)
```

Users:
```bash
brew tap thingstead/homebrew-tap
brew install git-cloak              # Latest stable
brew install git-cloak@edge         # Development version
```

### Example 3: Templated formula (Liquid)

For similar projects, use Homebrew formula inheritance:

```ruby
# Formula/base-tool.rb (base template)
class BaseTool < Formula
  # Common definitions
end

# Formula/git-cloak.rb
class GitCloak < BaseTool
  desc "Personal file overlay for git"
  homepage "https://github.com/thingstead/git-cloak"
  url "..."
end
```

## Testing Formulas Locally

```bash
# Install from local tap
brew tap-new local/formulae
cd local/formulae
cp /path/to/git-cloak.rb Formula/
brew install local/formulae/git-cloak

# Or test directly
brew install --build-from-source Formula/git-cloak.rb

# Verify
which git-cloak
git-cloak --version
```

## Managing the Tap

### README template for thingstead/homebrew-tap:

```markdown
# Thingstead Homebrew Tap

A collection of useful tools from Thingstead.

## Installation

```bash
brew tap thingstead/homebrew-tap
brew install git-cloak
brew install other-tool
```

## Tools

- **git-cloak** - Personal file overlay manager for git
- **other-tool** - Description here
- **another-tool** - Description here

## Updates

```bash
brew update
brew upgrade
```

## Uninstall

```bash
brew uninstall git-cloak
brew untap thingstead/homebrew-tap
```
```

### Removing old formulas

If you remove a tool:

```bash
rm Formula/old-tool.rb
git add -A
git commit -m "Remove old-tool from tap"
git push
```

Users won't see it anymore, but existing installations remain.

## FAQ

**Q: Can I move a tool from one tap to another?**
A: Yes. Update the formula URL to point to the new tap's repository. Users will get the new version next time they update.

**Q: What if formula names conflict?**
A: Homebrew uses the formula filename, so `git-cloak.rb` creates the `git-cloak` command. Choose unique names per tool.

**Q: Can I have private formulas?**
A: Yes, but the tap repo must be public. Use private source code repositories instead.

**Q: How do I handle dependencies between formulas?**
A: Use Homebrew's `depends_on` in formulas. Example:
```ruby
depends_on "git"
depends_on "thingstead/homebrew-tap/git-cloak"
```

## Resources

- [Homebrew Tap Documentation](https://docs.brew.sh/Taps)
- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [Bottle Format for Distribution](https://docs.brew.sh/Bottles)
