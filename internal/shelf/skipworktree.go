package shelf

import (
	"fmt"

	"github.com/jwill824/git-shelf/internal/git"
)

// SetSkipWorktree marks a tracked file so git ignores local changes.
func SetSkipWorktree(repo *git.Repo, path string) error {
	_, err := repo.Run("update-index", "--skip-worktree", path)
	if err != nil {
		return fmt.Errorf("set skip-worktree %s: %w", path, err)
	}
	return nil
}

// ClearSkipWorktree removes the skip-worktree flag from a tracked file.
func ClearSkipWorktree(repo *git.Repo, path string) error {
	_, err := repo.Run("update-index", "--no-skip-worktree", path)
	if err != nil {
		return fmt.Errorf("clear skip-worktree %s: %w", path, err)
	}
	return nil
}
