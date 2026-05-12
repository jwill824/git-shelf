package shelf

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/jwill824/git-shelf/internal/git"
)

// HashObject writes file content to the git object store and returns its SHA.
func HashObject(repo *git.Repo, filePath string) (string, error) {
	sha, err := repo.Run("hash-object", "-w", filePath)
	if err != nil {
		return "", fmt.Errorf("hash-object %s: %w", filePath, err)
	}
	return sha, nil
}

// CatFileBlob retrieves blob content by SHA without trimming.
func CatFileBlob(repo *git.Repo, sha string) ([]byte, error) {
	cmd := exec.Command("git", "cat-file", "blob", sha)
	cmd.Dir = repo.Root
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("cat-file blob %s: %w", sha, err)
	}
	return out, nil
}

// LSFilesSHA returns the blob SHA of a tracked file in the current index.
// Returns "" if the file is not tracked.
func LSFilesSHA(repo *git.Repo, filePath string) (string, error) {
	out, err := repo.Run("ls-files", "-s", filePath)
	if err != nil || strings.TrimSpace(out) == "" {
		return "", nil
	}
	// Output format: <mode> <sha> <stage>\t<file>
	fields := strings.Fields(out)
	if len(fields) < 2 {
		return "", nil
	}
	return fields[1], nil
}

// WriteBlob writes the content of a git blob to destPath, creating parent dirs.
func WriteBlob(repo *git.Repo, sha string, destPath string) error {
	content, err := CatFileBlob(repo, sha)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(destPath), 0755); err != nil {
		return fmt.Errorf("mkdir: %w", err)
	}
	return os.WriteFile(destPath, content, 0644)
}
