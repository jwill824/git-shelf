package main

import (
	"fmt"

	"github.com/spf13/cobra"
	"github.com/jwill824/git-shelf/internal/git"
	"github.com/jwill824/git-shelf/internal/shelf"
)

var listCmd = &cobra.Command{
	Use:   "list",
	Short: "Show all shelved files and their sync status",
	RunE:  runList,
}

func runList(_ *cobra.Command, _ []string) error {
	repo, err := git.Open(".")
	if err != nil {
		return fmt.Errorf("not in a git repository")
	}

	entries, err := shelf.ReadIndex(repo.GitDir)
	if err != nil {
		return err
	}
	if len(entries) == 0 {
		fmt.Println("No files on shelf.")
		return nil
	}

	conflicts, err := shelf.DetectConflicts(repo, entries)
	if err != nil {
		return err
	}
	conflictPaths := make(map[string]bool)
	for _, c := range conflicts {
		conflictPaths[c.Entry.Path] = true
	}

	for _, e := range entries {
		status := "✓ in sync"
		if conflictPaths[e.Path] {
			status = "⚠ diverged"
		}
		fmt.Printf("  %-40s %s  [%s]\n", e.Path, status, e.Type)
	}
	return nil
}
