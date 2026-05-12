package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
	"github.com/jwill824/git-shelf/internal/git"
	"github.com/jwill824/git-shelf/internal/shelf"
)

var removeCmd = &cobra.Command{
	Use:   "remove <file>",
	Short: "Un-shelf a file and restore the repo version",
	Args:  cobra.ExactArgs(1),
	RunE:  runRemove,
}

func runRemove(_ *cobra.Command, args []string) error {
	filePath := args[0]
	repo, err := git.Open(".")
	if err != nil {
		return fmt.Errorf("not in a git repository")
	}

	entries, err := shelf.ReadIndex(repo.GitDir)
	if err != nil {
		return err
	}

	entry, ok := shelf.FindEntry(entries, filePath)
	if !ok {
		return fmt.Errorf("%s is not shelved", filePath)
	}

	if entry.Type == shelf.EntryTypeTracked {
		shelf.ClearSkipWorktree(repo, filePath)
		// Restore the repo's HEAD version
		if _, err := repo.Run("checkout", "HEAD", "--", filePath); err != nil {
			return fmt.Errorf("restore repo version: %w", err)
		}
	} else {
		// Untracked: delete the personal file
		os.Remove(filepath.Join(repo.Root, filePath))
	}

	entries = shelf.RemoveEntry(entries, filePath)
	if err := shelf.WriteIndex(repo.GitDir, entries); err != nil {
		return err
	}

	fmt.Printf("Removed from shelf: %s\n", filePath)
	return nil
}
