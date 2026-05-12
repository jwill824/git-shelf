package shelf

import (
	"fmt"
	"path/filepath"

	"github.com/jwill824/git-shelf/internal/git"
)

// ConflictInfo describes a shelved file whose upstream version has diverged.
type ConflictInfo struct {
	Entry        Entry
	UpstreamBlob string // current blob SHA in the repo index
}

// DetectConflicts checks each shelved entry against the current repo index.
// Returns entries where the upstream blob differs from both the base and personal blobs.
func DetectConflicts(repo *git.Repo, entries []Entry) ([]ConflictInfo, error) {
	var conflicts []ConflictInfo
	for _, e := range entries {
		currentBlob, err := LSFilesSHA(repo, e.Path)
		if err != nil {
			return nil, fmt.Errorf("ls-files %s: %w", e.Path, err)
		}
		// No conflict if upstream matches base (unchanged) or already is personal version
		if currentBlob == e.BaseBlob || currentBlob == e.PersonalBlob || currentBlob == "" {
			continue
		}
		conflicts = append(conflicts, ConflictInfo{Entry: e, UpstreamBlob: currentBlob})
	}
	return conflicts, nil
}

// RestoreEntries writes each entry's personal blob back to the working tree
// and re-applies skip-worktree for tracked files.
func RestoreEntries(repo *git.Repo, entries []Entry) error {
	for _, e := range entries {
		dest := filepath.Join(repo.Root, e.Path)
		if err := WriteBlob(repo, e.PersonalBlob, dest); err != nil {
			return fmt.Errorf("restore %s: %w", e.Path, err)
		}
		if e.Type == EntryTypeTracked {
			if err := SetSkipWorktree(repo, e.Path); err != nil {
				return fmt.Errorf("skip-worktree %s: %w", e.Path, err)
			}
		}
	}
	return nil
}
