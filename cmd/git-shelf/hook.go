package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
	"github.com/jwill824/git-shelf/internal/git"
	"github.com/jwill824/git-shelf/internal/shelf"
	"github.com/jwill824/git-shelf/internal/tui"
)

var hookCmd = &cobra.Command{
	Use:    "hook <type>",
	Hidden: true, // not shown in help
	Short:  "Internal: called by git hooks",
	Args:   cobra.MinimumNArgs(1),
	RunE:   runHook,
}

func runHook(cmd *cobra.Command, args []string) error {
	hookType := args[0]

	// post-checkout: args[1]=prev, args[2]=new, args[3]=flag (1=branch,0=file)
	if hookType == "post-checkout" && len(args) >= 4 && args[3] != "1" {
		return nil // file checkout, not branch switch — skip
	}

	repo, err := git.Open(".")
	if err != nil {
		return nil // not in a repo, silently exit
	}

	entries, err := shelf.ReadIndex(repo.GitDir)
	if err != nil || len(entries) == 0 {
		return nil
	}

	conflicts, err := shelf.DetectConflicts(repo, entries)
	if err != nil {
		fmt.Fprintf(os.Stderr, "git-shelf: conflict detection failed: %v\n", err)
		return nil
	}

	if len(conflicts) > 0 {
		conflictInputs := make([]tui.Conflict, len(conflicts))
		for i, c := range conflicts {
			conflictInputs[i] = tui.Conflict{
				Path:         c.Entry.Path,
				PersonalBlob: c.Entry.PersonalBlob,
				UpstreamBlob: c.UpstreamBlob,
			}
		}

		resolutions, err := tui.RunConflictUI(conflictInputs)
		if err != nil {
			fmt.Fprintf(os.Stderr, "git-shelf: tui error: %v\n", err)
			// Fall back to keeping personal version
			return shelf.RestoreEntries(repo, entries)
		}

		if err := applyResolutions(repo, resolutions, entries); err != nil {
			fmt.Fprintf(os.Stderr, "git-shelf: resolution failed: %v\n", err)
		}
	}

	// Restore all non-conflicted entries silently
	nonConflicted := nonConflictedEntries(entries, conflicts)
	return shelf.RestoreEntries(repo, nonConflicted)
}

func applyResolutions(repo *git.Repo, resolutions []tui.Resolution, entries []shelf.Entry) error {
	for _, r := range resolutions {
		entry, ok := shelf.FindEntry(entries, r.Conflict.Path)
		if !ok {
			continue
		}
		switch r.Action {
		case tui.ActionKeepMine:
			if err := shelf.RestoreEntries(repo, []shelf.Entry{entry}); err != nil {
				return err
			}
		case tui.ActionTakeTheirs:
			// Update personal blob to upstream version, update base blob
			entry.PersonalBlob = r.Conflict.UpstreamBlob
			entry.BaseBlob = r.Conflict.UpstreamBlob
			allEntries, _ := shelf.ReadIndex(repo.GitDir)
			allEntries = shelf.AddEntry(allEntries, entry)
			shelf.WriteIndex(repo.GitDir, allEntries)
			shelf.RestoreEntries(repo, []shelf.Entry{entry})
		case tui.ActionOpenEditor:
			personalContent, _ := shelf.CatFileBlob(repo, r.Conflict.PersonalBlob)
			upstreamContent, _ := shelf.CatFileBlob(repo, r.Conflict.UpstreamBlob)
			resolved, err := tui.OpenEditorForConflict(r.Conflict, personalContent, upstreamContent)
			if err == nil && resolved != nil {
				dest := filepath.Join(repo.Root, entry.Path)
				os.WriteFile(dest, resolved, 0644)
				newBlob, _ := shelf.HashObject(repo, entry.Path)
				entry.PersonalBlob = newBlob
				allEntries, _ := shelf.ReadIndex(repo.GitDir)
				allEntries = shelf.AddEntry(allEntries, entry)
				shelf.WriteIndex(repo.GitDir, allEntries)
				shelf.SetSkipWorktree(repo, entry.Path)
			}
		}
	}
	return nil
}

func nonConflictedEntries(entries []shelf.Entry, conflicts []shelf.ConflictInfo) []shelf.Entry {
	conflictPaths := make(map[string]bool)
	for _, c := range conflicts {
		conflictPaths[c.Entry.Path] = true
	}
	var out []shelf.Entry
	for _, e := range entries {
		if !conflictPaths[e.Path] {
			out = append(out, e)
		}
	}
	return out
}
