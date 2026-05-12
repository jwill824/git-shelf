package shelf_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/thingstead/git-shelf/internal/git"
	"github.com/thingstead/git-shelf/internal/shelf"
)

func setupRepo(t *testing.T) *git.Repo {
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
	repo, err := git.Open(dir)
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	return repo
}

func writeFile(t *testing.T, repo *git.Repo, name, content string) {
	t.Helper()
	path := filepath.Join(repo.Root, name)
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatalf("WriteFile: %v", err)
	}
}

func TestHashObject(t *testing.T) {
	repo := setupRepo(t)
	writeFile(t, repo, "config.yml", "key: personal-value\n")

	sha, err := shelf.HashObject(repo, "config.yml")
	if err != nil {
		t.Fatalf("HashObject: %v", err)
	}
	if len(sha) != 40 {
		t.Errorf("sha = %q, want 40-char SHA", sha)
	}
}

func TestCatFileBlob(t *testing.T) {
	repo := setupRepo(t)
	content := "key: personal-value\n"
	writeFile(t, repo, "config.yml", content)

	sha, _ := shelf.HashObject(repo, "config.yml")
	got, err := shelf.CatFileBlob(repo, sha)
	if err != nil {
		t.Fatalf("CatFileBlob: %v", err)
	}
	if string(got) != content {
		t.Errorf("content = %q, want %q", got, content)
	}
}

func TestLSFilesSHA(t *testing.T) {
	repo := setupRepo(t)
	writeFile(t, repo, "tracked.txt", "repo version\n")
	exec.Command("git", "-C", repo.Root, "add", "tracked.txt").Run()
	exec.Command("git", "-C", repo.Root, "commit", "-m", "init").Run()

	sha, err := shelf.LSFilesSHA(repo, "tracked.txt")
	if err != nil {
		t.Fatalf("LSFilesSHA: %v", err)
	}
	if len(sha) != 40 {
		t.Errorf("sha = %q, want 40-char SHA", sha)
	}
}

func TestLSFilesSHA_Untracked(t *testing.T) {
	repo := setupRepo(t)
	writeFile(t, repo, "new.txt", "personal only\n")

	sha, err := shelf.LSFilesSHA(repo, "new.txt")
	if err != nil {
		t.Fatalf("LSFilesSHA for untracked: %v", err)
	}
	if sha != "" {
		t.Errorf("expected empty sha for untracked, got %q", sha)
	}
}

func TestWriteBlob(t *testing.T) {
	repo := setupRepo(t)
	content := "restored content\n"
	writeFile(t, repo, "source.txt", content)
	sha, _ := shelf.HashObject(repo, "source.txt")

	dest := filepath.Join(repo.Root, "output.txt")
	if err := shelf.WriteBlob(repo, sha, dest); err != nil {
		t.Fatalf("WriteBlob: %v", err)
	}
	got, _ := os.ReadFile(dest)
	if string(got) != content {
		t.Errorf("restored content = %q, want %q", got, content)
	}
}

func TestSkipWorktree(t *testing.T) {
	repo := setupRepo(t)
	writeFile(t, repo, "tracked.txt", "repo version\n")
	exec.Command("git", "-C", repo.Root, "add", "tracked.txt").Run()
	exec.Command("git", "-C", repo.Root, "commit", "-m", "init").Run()

	if err := shelf.SetSkipWorktree(repo, "tracked.txt"); err != nil {
		t.Fatalf("SetSkipWorktree: %v", err)
	}

	// Verify flag is set via git ls-files output
	out, _ := exec.Command("git", "-C", repo.Root, "ls-files", "-v", "tracked.txt").Output()
	if !strings.HasPrefix(string(out), "S") {
		t.Errorf("expected skip-worktree flag (S), got: %q", out)
	}

	if err := shelf.ClearSkipWorktree(repo, "tracked.txt"); err != nil {
		t.Fatalf("ClearSkipWorktree: %v", err)
	}
	out, _ = exec.Command("git", "-C", repo.Root, "ls-files", "-v", "tracked.txt").Output()
	if strings.HasPrefix(string(out), "S") {
		t.Errorf("expected no skip-worktree flag after clear, got: %q", out)
	}
}
