package main

import (
	"fmt"

	"github.com/spf13/cobra"
	"github.com/jwill824/git-shelf/internal/git"
	"github.com/jwill824/git-shelf/internal/shelf"
)

var syncCmd = &cobra.Command{
	Use:   "sync",
	Short: "Re-apply all shelved files (recovery command)",
	RunE:  runSync,
}

func runSync(_ *cobra.Command, _ []string) error {
	repo, err := git.Open(".")
	if err != nil {
		return fmt.Errorf("not in a git repository")
	}

	entries, err := shelf.ReadIndex(repo.GitDir)
	if err != nil {
		return err
	}
	if len(entries) == 0 {
		fmt.Println("Nothing on shelf.")
		return nil
	}

	if err := shelf.RestoreEntries(repo, entries); err != nil {
		return fmt.Errorf("sync failed: %w", err)
	}

	fmt.Printf("Synced %d shelved file(s).\n", len(entries))
	return nil
}
