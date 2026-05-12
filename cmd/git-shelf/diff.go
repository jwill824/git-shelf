package main

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/spf13/cobra"
	"github.com/jwill824/git-shelf/internal/git"
	"github.com/jwill824/git-shelf/internal/shelf"
)

var diffCmd = &cobra.Command{
	Use:   "diff [file]",
	Short: "Show diff between personal version and repo version",
	Args:  cobra.MaximumNArgs(1),
	RunE:  runDiff,
}

func runDiff(_ *cobra.Command, args []string) error {
	repo, err := git.Open(".")
	if err != nil {
		return fmt.Errorf("not in a git repository")
	}

	entries, err := shelf.ReadIndex(repo.GitDir)
	if err != nil {
		return err
	}

	if len(args) == 1 {
		e, ok := shelf.FindEntry(entries, args[0])
		if !ok {
			return fmt.Errorf("%s is not shelved", args[0])
		}
		entries = []shelf.Entry{e}
	}

	for _, e := range entries {
		currentBlob, _ := shelf.LSFilesSHA(repo, e.Path)
		if currentBlob == "" || currentBlob == e.PersonalBlob {
			continue
		}
		fmt.Printf("--- %s (repo)\n+++ %s (shelf)\n", e.Path, e.Path)
		cmd := exec.Command("git", "-C", repo.Root, "diff", currentBlob, e.PersonalBlob)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		cmd.Run() //nolint:errcheck // display only; errors shown on stderr
	}
	return nil
}
