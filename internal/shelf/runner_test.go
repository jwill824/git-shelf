package shelf_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/jwill824/git-shelf/internal/git"
	"github.com/jwill824/git-shelf/internal/shelf"
)

func commitFile(t *testing.T, repo *git.Repo, name, content string) {
	t.Helper()
	writeFile(t, repo, name, content)
	exec.Command("git", "-C", repo.Root, "add", name).Run()
	exec.Command("git", "-C", repo.Root, "commit", "-m", "add "+name).Run()
}

func TestDetectConflicts_NoConflict(t *testing.T) {
	repo := setupRepo(t)
	commitFile(t, repo, "config.yml", "repo: version\n")

	// Shelve the file (write personal blob, record base blob)
	writeFile(t, repo, "config.yml", "personal: version\n")
	personalBlob, _ := shelf.HashObject(repo, "config.yml")
	baseBlob, _ := shelf.LSFilesSHA(repo, "config.yml")

	entries := []shelf.Entry{{
		Path: "config.yml", PersonalBlob: personalBlob,
		BaseBlob: baseBlob, Type: shelf.EntryTypeTracked,
	}}

	// No upstream change: current blob == base blob
	conflicts, err := shelf.DetectConflicts(repo, entries)
	if err != nil {
		t.Fatalf("DetectConflicts: %v", err)
	}
	if len(conflicts) != 0 {
		t.Errorf("expected no conflicts, got %d", len(conflicts))
	}
}

func TestDetectConflicts_WithConflict(t *testing.T) {
	repo := setupRepo(t)
	commitFile(t, repo, "config.yml", "repo: version\n")

	baseBlob, _ := shelf.LSFilesSHA(repo, "config.yml")
	personalBlob, _ := shelf.HashObject(repo, "config.yml")

	// Simulate upstream change: amend the commit with different content
	writeFile(t, repo, "config.yml", "repo: changed-upstream\n")
	exec.Command("git", "-C", repo.Root, "add", "config.yml").Run()
	exec.Command("git", "-C", repo.Root, "commit", "--amend", "--no-edit").Run()

	entries := []shelf.Entry{{
		Path: "config.yml", PersonalBlob: personalBlob,
		BaseBlob: baseBlob, Type: shelf.EntryTypeTracked,
	}}

	conflicts, err := shelf.DetectConflicts(repo, entries)
	if err != nil {
		t.Fatalf("DetectConflicts: %v", err)
	}
	if len(conflicts) != 1 {
		t.Errorf("expected 1 conflict, got %d", len(conflicts))
	}
}

func TestRestoreEntries(t *testing.T) {
	repo := setupRepo(t)
	commitFile(t, repo, "tracked.txt", "repo version\n")
	personalContent := "my personal version\n"
	writeFile(t, repo, "tracked.txt", personalContent)
	personalBlob, _ := shelf.HashObject(repo, "tracked.txt")
	baseBlob, _ := shelf.LSFilesSHA(repo, "tracked.txt")

	entries := []shelf.Entry{{
		Path: "tracked.txt", PersonalBlob: personalBlob,
		BaseBlob: baseBlob, Type: shelf.EntryTypeTracked,
	}}

	// Overwrite with repo content (simulates what a branch switch does)
	writeFile(t, repo, "tracked.txt", "repo version\n")

	if err := shelf.RestoreEntries(repo, entries); err != nil {
		t.Fatalf("RestoreEntries: %v", err)
	}

	got, _ := os.ReadFile(filepath.Join(repo.Root, "tracked.txt"))
	if string(got) != personalContent {
		t.Errorf("restored content = %q, want %q", got, personalContent)
	}
}
