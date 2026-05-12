package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
	"github.com/thingstead/git-shelf/internal/git"
	"github.com/thingstead/git-shelf/internal/shelf"
)

var initCmd = &cobra.Command{
	Use:   "init",
	Short: "Initialize git-shelf for this repository",
	RunE:  runInit,
}

func runInit(_ *cobra.Command, _ []string) error {
	repo, err := git.Open(".")
	if err != nil {
		return fmt.Errorf("not in a git repository")
	}

	personalDir := filepath.Join(repo.GitDir, "personal")
	if err := os.MkdirAll(personalDir, 0755); err != nil {
		return fmt.Errorf("create .git/personal: %w", err)
	}

	if err := shelf.InstallHooks(repo.GitDir); err != nil {
		return fmt.Errorf("install hooks: %w", err)
	}

	fmt.Println("git-shelf initialized. Hooks installed for post-checkout, post-merge, post-rewrite.")
	return nil
}
