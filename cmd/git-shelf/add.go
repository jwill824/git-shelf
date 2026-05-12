package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/thingstead/git-shelf/internal/git"
	"github.com/thingstead/git-shelf/internal/shelf"
)

var addCmd = &cobra.Command{
	Use:   "add <file>",
	Short: "Shelf a file at your personal version",
	Args:  cobra.ExactArgs(1),
	RunE:  runAdd,
}

func runAdd(_ *cobra.Command, args []string) error {
	filePath := args[0]
	repo, err := git.Open(".")
	if err != nil {
		return fmt.Errorf("not in a git repository")
	}

	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		return fmt.Errorf("file not found: %s", filePath)
	}

	personalBlob, err := shelf.HashObject(repo, filePath)
	if err != nil {
		return fmt.Errorf("hash-object: %w", err)
	}

	// Check if tracked
	baseBlob, err := shelf.LSFilesSHA(repo, filePath)
	if err != nil {
		return err
	}

	entryType := shelf.EntryTypeUntracked
	if baseBlob != "" {
		entryType = shelf.EntryTypeTracked
		if err := shelf.SetSkipWorktree(repo, filePath); err != nil {
			return fmt.Errorf("skip-worktree: %w", err)
		}
	}

	entry := shelf.Entry{
		Path:         filePath,
		PersonalBlob: personalBlob,
		BaseBlob:     baseBlob,
		Type:         entryType,
	}

	entries, err := shelf.ReadIndex(repo.GitDir)
	if err != nil {
		return err
	}
	entries = shelf.AddEntry(entries, entry)
	if err := shelf.WriteIndex(repo.GitDir, entries); err != nil {
		return err
	}

	fmt.Printf("Shelved: %s\n", filePath)
	return nil
}
