package shelf_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/jwill824/git-shelf/internal/shelf"
)

// TestShelfSurvivesBranchSwitch verifies that after shelving a file and switching
// branches, the personal version is restored.
func TestShelfSurvivesBranchSwitch(t *testing.T) {
	repo := setupRepo(t)
	commitFile(t, repo, "config.yml", "repo: main-version\n")

	// Shelve personal version
	writeFile(t, repo, "config.yml", "personal: my-version\n")
	personalBlob, _ := shelf.HashObject(repo, "config.yml")
	baseBlob, _ := shelf.LSFilesSHA(repo, "config.yml")
	shelf.SetSkipWorktree(repo, "config.yml")

	entries := []shelf.Entry{{
		Path: "config.yml", PersonalBlob: personalBlob,
		BaseBlob: baseBlob, Type: shelf.EntryTypeTracked,
	}}
	shelf.WriteIndex(repo.GitDir, entries)

	// Create and switch to new branch (no upstream change to config.yml)
	exec.Command("git", "-C", repo.Root, "checkout", "-b", "feature").Run()

	// Detect conflicts (should be none) and restore
	conflicts, err := shelf.DetectConflicts(repo, entries)
	if err != nil {
		t.Fatalf("DetectConflicts: %v", err)
	}
	if len(conflicts) != 0 {
		t.Fatalf("expected no conflicts, got %d", len(conflicts))
	}

	shelf.RestoreEntries(repo, entries)

	got, _ := os.ReadFile(filepath.Join(repo.Root, "config.yml"))
	if string(got) != "personal: my-version\n" {
		t.Errorf("after branch switch, got %q, want personal version", got)
	}
}

// TestUntrackedFileShelved verifies untracked files are shelved and restored.
func TestUntrackedFileShelved(t *testing.T) {
	repo := setupRepo(t)
	commitFile(t, repo, "README.md", "readme\n")

	// Add an untracked personal file
	writeFile(t, repo, ".env.local", "SECRET=mine\n")
	personalBlob, _ := shelf.HashObject(repo, ".env.local")

	entries := []shelf.Entry{{
		Path: ".env.local", PersonalBlob: personalBlob,
		BaseBlob: "", Type: shelf.EntryTypeUntracked,
	}}
	shelf.WriteIndex(repo.GitDir, entries)

	// Restore: should write the file
	writeFile(t, repo, ".env.local", "wrong content\n")
	shelf.RestoreEntries(repo, entries)

	got, _ := os.ReadFile(filepath.Join(repo.Root, ".env.local"))
	if string(got) != "SECRET=mine\n" {
		t.Errorf("untracked restore: got %q", got)
	}
}
