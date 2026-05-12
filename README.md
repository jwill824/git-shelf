# git-shelf

> Personal file overlay manager for git — carry your changes across branches without a dedicated branch.

## Installation

```bash
brew tap jwill824/tap
brew install git-shelf
```

## Quick start

```bash
git shelf init           # run once per repo
git shelf add <file>     # shelf a file at your version
git shelf list           # see what's shelved
git shelf promote <br>   # eject to a real branch when ready
```

## Documentation

- [Full docs](docs/README.md) — complete command reference and how it works
- [Homebrew](docs/HOMEBREW.md) — tap setup, releases, and formula management
- [Contributing](docs/CONTRIBUTING.md) — development workflow

## License

MIT
