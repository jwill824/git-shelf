# Contributing

## Getting started

```bash
git clone https://github.com/jwill824/git-shelf.git
cd git-shelf
go build ./...
go test ./...
```

## Development workflow

1. Create a feature branch: `git checkout -b feat/your-feature`
2. Make changes and add tests
3. Run tests: `go test ./...`
4. Commit using [Conventional Commits](https://www.conventionalcommits.org/)
5. Open a pull request against `main`

## Pull requests

- Squash merge only — one commit per PR
- PR title must follow Conventional Commits format

## Project structure

```
cmd/git-shelf/     # CLI entry points (cobra commands)
internal/git/      # git repo abstraction
internal/shelf/    # core shelf logic (index, blobs, hooks, runner)
internal/tui/      # Bubbletea conflict resolution UI
Formula/           # Homebrew formula (reference copy)
docs/              # documentation
```

## Running tests

```bash
go test ./...                        # all tests
go test ./internal/shelf/...         # shelf package only
go test -run TestShelfSurvives...    # specific test
```

## Building

```bash
go build -o git-shelf ./cmd/git-shelf
```

