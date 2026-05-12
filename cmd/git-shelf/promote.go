package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/spf13/cobra"
	"github.com/thingstead/git-shelf/internal/git"
	"github.com/thingstead/git-shelf/internal/shelf"
)

var promoteCmd = &cobra.Command{
	Use:   "promote <branch-name>",
	Short: "Promote all shelved files to a new git branch (PR-ready)",
	Long: `Creates a new branch from HEAD, commits all shelved files as real git commits.
Use 'git shelf remove <file>' first to exclude specific files from promotion.
The shelf is preserved after promotion.`,
	Args: cobra.ExactArgs(1),
	RunE: runPromote,
}

func runPromote(_ *cobra.Command, args []string) error {
	branchName := args[0]
	repo, err := git.Open(".")
	if err != nil {
		return fmt.Errorf("not in a git repository")
	}

	entries, err := shelf.ReadIndex(repo.GitDir)
	if err != nil {
		return err
	}
	if len(entries) == 0 {
		return fmt.Errorf("nothing on shelf to promote")
	}

	// Create branch from HEAD (post-checkout hook fires but is a no-op: no upstream changes)
	if _, err := repo.Run("checkout", "-b", branchName); err != nil {
		return fmt.Errorf("create branch %s: %w", branchName, err)
	}

	// Clear skip-worktree so git can stage the files
	for _, e := range entries {
		if e.Type == shelf.EntryTypeTracked {
			shelf.ClearSkipWorktree(repo, e.Path)
		}
	}

	// Write personal blobs to working tree and stage
	filePaths := make([]string, 0, len(entries))
	for _, e := range entries {
		dest := filepath.Join(repo.Root, e.Path)
		if err := shelf.WriteBlob(repo, e.PersonalBlob, dest); err != nil {
			return fmt.Errorf("write %s: %w", e.Path, err)
		}
		filePaths = append(filePaths, e.Path)
	}

	addArgs := append([]string{"-C", repo.Root, "add"}, filePaths...)
	if out, err := exec.Command("git", addArgs...).CombinedOutput(); err != nil {
		return fmt.Errorf("git add: %s", out)
	}

	if _, err := repo.Run("commit", "-m", "Personal shelf changes"); err != nil {
		return fmt.Errorf("commit: %w", err)
	}

	// Re-apply skip-worktree to restore shelf state
	for _, e := range entries {
		if e.Type == shelf.EntryTypeTracked {
			shelf.SetSkipWorktree(repo, e.Path)
		}
	}

	fmt.Printf("Promoted %d file(s) to branch '%s'.\n", len(entries), branchName)

	// Offer to push if gh is available
	if _, err := exec.LookPath("gh"); err == nil {
		fmt.Print("Open a PR now? [y/N] ")
		var answer string
		fmt.Scanln(&answer)
		if answer == "y" || answer == "Y" {
			cmd := exec.Command("gh", "pr", "create", "--fill")
			cmd.Stdin = os.Stdin
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			cmd.Run()
		}
	}

	return nil
}
