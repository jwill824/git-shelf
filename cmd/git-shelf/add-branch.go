package main

import (
	"fmt"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
	"github.com/jwill824/git-shelf/internal/git"
	"github.com/jwill824/git-shelf/internal/shelf"
)

var addBranchBase string

var addBranchCmd = &cobra.Command{
	Use:   "add-branch [<branch>]",
	Short: "Shelf all files changed on a branch",
	Long: `Shelves every added or modified file on the given branch (default: current HEAD)
relative to its merge-base with --base (default: main).
Deleted files are reported and skipped.`,
	Args: cobra.MaximumNArgs(1),
	RunE: runAddBranch,
}

func init() {
	addBranchCmd.Flags().StringVar(&addBranchBase, "base", "main", "base branch to diff against")
}

func runAddBranch(_ *cobra.Command, args []string) error {
	repo, err := git.Open(".")
	if err != nil {
		return fmt.Errorf("not in a git repository")
	}

	target := "HEAD"
	if len(args) == 1 {
		target = args[0]
	}

	mergeBase, err := repo.Run("merge-base", addBranchBase, target)
	if err != nil {
		return fmt.Errorf("could not find merge-base between %s and %s: %w", addBranchBase, target, err)
	}

	diffOut, err := repo.Run("diff", "--name-status", mergeBase+"..."+target)
	if err != nil {
		return fmt.Errorf("git diff: %w", err)
	}
	if strings.TrimSpace(diffOut) == "" {
		fmt.Println("No changes found on branch.")
		return nil
	}

	entries, err := shelf.ReadIndex(repo.GitDir)
	if err != nil {
		return err
	}

	var shelved, skipped int
	for _, line := range strings.Split(diffOut, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		status := fields[0]
		// Renames ("R<score> old new") — shelf the destination path
		filePath := fields[len(fields)-1]

		if strings.HasPrefix(status, "D") {
			fmt.Printf("  skip (deleted):  %s\n", filePath)
			skipped++
			continue
		}

		personalBlob, err := lsTreeBlob(repo, target, filePath)
		if err != nil {
			fmt.Printf("  skip (error):    %s: %v\n", filePath, err)
			skipped++
			continue
		}

		baseBlob, err := shelf.LSFilesSHA(repo, filePath)
		if err != nil {
			return err
		}

		entryType := shelf.EntryTypeUntracked
		if baseBlob != "" {
			entryType = shelf.EntryTypeTracked
			dest := filepath.Join(repo.Root, filePath)
			if err := shelf.WriteBlob(repo, personalBlob, dest); err != nil {
				return fmt.Errorf("write %s: %w", filePath, err)
			}
			if err := shelf.SetSkipWorktree(repo, filePath); err != nil {
				return fmt.Errorf("skip-worktree %s: %w", filePath, err)
			}
		}

		entries = shelf.AddEntry(entries, shelf.Entry{
			Path:         filePath,
			PersonalBlob: personalBlob,
			BaseBlob:     baseBlob,
			Type:         entryType,
		})
		fmt.Printf("  shelved:         %s\n", filePath)
		shelved++
	}

	if err := shelf.WriteIndex(repo.GitDir, entries); err != nil {
		return err
	}

	fmt.Printf("\nShelved %d file(s)", shelved)
	if skipped > 0 {
		fmt.Printf(", skipped %d (deleted)", skipped)
	}
	fmt.Println(".")
	return nil
}

// lsTreeBlob returns the blob SHA for filePath at the given ref.
// The blob is already in the object store as part of the ref's commit tree.
func lsTreeBlob(repo *git.Repo, ref, filePath string) (string, error) {
	out, err := repo.Run("ls-tree", ref, filePath)
	if err != nil || strings.TrimSpace(out) == "" {
		return "", fmt.Errorf("not found at %s", ref)
	}
	// Format: "<mode> blob <sha>\t<file>"
	fields := strings.Fields(out)
	if len(fields) < 3 {
		return "", fmt.Errorf("unexpected ls-tree output: %q", out)
	}
	return fields[2], nil
}
