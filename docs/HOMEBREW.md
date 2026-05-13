# Homebrew Distribution

git-shelf is distributed via a [Homebrew tap](https://docs.brew.sh/Taps) at `jwill824/homebrew-tap`.

## Installing

```bash
brew tap jwill824/tap
brew install git-shelf
```

## Updating

```bash
brew update
brew upgrade git-shelf
```

## Uninstalling

```bash
brew uninstall git-shelf
brew untap jwill824/tap
```

---

## Release process (maintainers)

### 1. Tag a release

Releases are driven by [Conventional Commits](https://www.conventionalcommits.org/). Push to `main` with a qualifying commit message and the release workflow creates a GitHub Release automatically:

| Commit prefix | Version bump |
|---|---|
| `feat:` | minor |
| `fix:`, `docs:`, `perf:`, `refactor:` | patch |
| `feat!:` or `BREAKING CHANGE:` | major |
| `test:`, `chore:` | no release |

### 2. Update the formula

The release workflow **automatically** updates `Formula/git-shelf.rb` in `jwill824/homebrew-tap` after each release. No manual steps required.

For manual updates if needed:

```bash
VERSION="x.y.z"
SHA256=$(curl -sL https://github.com/jwill824/git-shelf/archive/refs/tags/v${VERSION}.tar.gz | shasum -a 256 | cut -d' ' -f1)
echo $SHA256
```

Then update the formula:

```ruby
url "https://github.com/jwill824/git-shelf/archive/refs/tags/vX.Y.Z.tar.gz"
sha256 "<paste-sha256-here>"
version "X.Y.Z"
```

Commit and push to `jwill824/homebrew-tap` — users will get the update on `brew update`.

### 3. Formula secrets

The release workflow uses the `GH_TOKEN` repository secret (provisioned via `jwill824/github-repo-factory`) to push formula updates to the tap automatically.

---

## Tap structure

The `jwill824/homebrew-tap` repository can host multiple formulas:

```
jwill824/homebrew-tap/
├── Formula/
│   ├── git-shelf.rb
│   └── other-tool.rb   # add more tools here
└── README.md
```

Users install any formula from the tap after a single `brew tap jwill824/tap`.
