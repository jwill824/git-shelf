package git

import (
	"fmt"
	"os/exec"
	"path/filepath"
	"strings"
)

// Repo represents an open git repository.
type Repo struct {
	Root   string // absolute path to the working tree root
	GitDir string // absolute path to the .git directory
}

// Open finds the git repo containing startDir and returns a Repo.
func Open(startDir string) (*Repo, error) {
	startDir, err := filepath.EvalSymlinks(startDir)
	if err != nil {
		return nil, fmt.Errorf("cannot resolve start path: %w", err)
	}
	root, err := runGit(startDir, "rev-parse", "--show-toplevel")
	if err != nil {
		return nil, fmt.Errorf("not a git repository: %w", err)
	}
	root, err = filepath.EvalSymlinks(root)
	if err != nil {
		return nil, fmt.Errorf("cannot resolve root path: %w", err)
	}
	gitDir, err := runGit(startDir, "rev-parse", "--git-dir")
	if err != nil {
		return nil, fmt.Errorf("cannot find .git dir: %w", err)
	}
	if !filepath.IsAbs(gitDir) {
		gitDir = filepath.Join(root, gitDir)
	}
	gitDir, err = filepath.EvalSymlinks(gitDir)
	if err != nil {
		return nil, fmt.Errorf("cannot resolve gitdir path: %w", err)
	}
	return &Repo{Root: root, GitDir: gitDir}, nil
}

// Run executes a git command in the repo root and returns trimmed stdout.
func (r *Repo) Run(args ...string) (string, error) {
	return runGit(r.Root, args...)
}

func runGit(dir string, args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	out, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}
