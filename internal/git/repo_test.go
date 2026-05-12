package git_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/thingstead/git-shelf/internal/git"
)

func initTempRepo(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	for _, args := range [][]string{
		{"init"},
		{"config", "user.email", "test@test.com"},
		{"config", "user.name", "Test"},
	} {
		cmd := exec.Command("git", args...)
		cmd.Dir = dir
		if err := cmd.Run(); err != nil {
			t.Fatalf("git %v: %v", args, err)
		}
	}
	return dir
}

func TestOpen(t *testing.T) {
	dir := initTempRepo(t)

	repo, err := git.Open(dir)
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	
	expectedRoot, _ := filepath.EvalSymlinks(dir)
	if repo.Root != expectedRoot {
		t.Errorf("Root = %q, want %q", repo.Root, expectedRoot)
	}
	expectedGitDir, _ := filepath.EvalSymlinks(filepath.Join(dir, ".git"))
	if repo.GitDir != expectedGitDir {
		t.Errorf("GitDir = %q, want %q", repo.GitDir, expectedGitDir)
	}
}

func TestOpen_NotARepo(t *testing.T) {
	dir := t.TempDir()
	_, err := git.Open(dir)
	if err == nil {
		t.Fatal("expected error for non-repo directory")
	}
}

func TestRun(t *testing.T) {
	dir := initTempRepo(t)
	repo, _ := git.Open(dir)

	out, err := repo.Run("rev-parse", "--git-dir")
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if out != ".git" {
		t.Errorf("output = %q, want %q", out, ".git")
	}
}

func TestOpenFromSubdir(t *testing.T) {
	dir := initTempRepo(t)
	subdir := filepath.Join(dir, "sub")
	os.MkdirAll(subdir, 0755)

	repo, err := git.Open(subdir)
	if err != nil {
		t.Fatalf("Open from subdir: %v", err)
	}
	expectedRoot, _ := filepath.EvalSymlinks(dir)
	if repo.Root != expectedRoot {
		t.Errorf("Root = %q, want %q", repo.Root, expectedRoot)
	}
}
