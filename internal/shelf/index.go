package shelf

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// EntryType distinguishes tracked files (in git index) from untracked personal files.
type EntryType string

const (
	EntryTypeTracked   EntryType = "tracked"
	EntryTypeUntracked EntryType = "untracked"
)

// Entry represents one shelved file.
type Entry struct {
	Path         string
	PersonalBlob string    // SHA of your personal version
	BaseBlob     string    // SHA of repo version at time of shelving; "" for untracked
	Type         EntryType
}

const indexFileName = "shelf-index"

func indexPath(gitDir string) string {
	return filepath.Join(gitDir, "personal", indexFileName)
}

// ReadIndex reads all entries from the shelf index. Returns empty slice if index doesn't exist.
func ReadIndex(gitDir string) ([]Entry, error) {
	path := indexPath(gitDir)
	f, err := os.Open(path)
	if os.IsNotExist(err) {
		return []Entry{}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("open index: %w", err)
	}
	defer f.Close()

	var entries []Entry
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.TrimSpace(line) == "" {
			continue
		}
		fields := strings.Split(line, "\t")
		if len(fields) != 4 {
			return nil, fmt.Errorf("malformed index line: %q", line)
		}
		entries = append(entries, Entry{
			Path:         fields[0],
			PersonalBlob: fields[1],
			BaseBlob:     fields[2],
			Type:         EntryType(fields[3]),
		})
	}
	return entries, scanner.Err()
}

// WriteIndex writes entries to the shelf index, overwriting any existing content.
func WriteIndex(gitDir string, entries []Entry) error {
	dir := filepath.Join(gitDir, "personal")
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("mkdir personal: %w", err)
	}
	f, err := os.Create(indexPath(gitDir))
	if err != nil {
		return fmt.Errorf("create index: %w", err)
	}
	defer f.Close()
	for _, e := range entries {
		fmt.Fprintf(f, "%s\t%s\t%s\t%s\n", e.Path, e.PersonalBlob, e.BaseBlob, e.Type)
	}
	return nil
}

// AddEntry appends or replaces an entry by path.
func AddEntry(entries []Entry, e Entry) []Entry {
	for i, existing := range entries {
		if existing.Path == e.Path {
			entries[i] = e
			return entries
		}
	}
	return append(entries, e)
}

// RemoveEntry removes an entry by path and returns the updated slice.
func RemoveEntry(entries []Entry, path string) []Entry {
	out := entries[:0]
	for _, e := range entries {
		if e.Path != path {
			out = append(out, e)
		}
	}
	return out
}

// FindEntry returns the entry for the given path, and whether it was found.
func FindEntry(entries []Entry, path string) (Entry, bool) {
	for _, e := range entries {
		if e.Path == path {
			return e, true
		}
	}
	return Entry{}, false
}
