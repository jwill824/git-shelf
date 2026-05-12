package shelf_test

import (
	"testing"

	"github.com/thingstead/git-shelf/internal/shelf"
)

func TestIndexRoundTrip(t *testing.T) {
	dir := t.TempDir()
	entries := []shelf.Entry{
		{Path: "config.yml", PersonalBlob: "abc123abc123abc123abc123abc123abc123abc1", BaseBlob: "def456def456def456def456def456def456def4", Type: shelf.EntryTypeTracked},
		{Path: ".env.local", PersonalBlob: "xyz789xyz789xyz789xyz789xyz789xyz789xyz7", BaseBlob: "", Type: shelf.EntryTypeUntracked},
	}

	if err := shelf.WriteIndex(dir, entries); err != nil {
		t.Fatalf("WriteIndex: %v", err)
	}
	got, err := shelf.ReadIndex(dir)
	if err != nil {
		t.Fatalf("ReadIndex: %v", err)
	}
	if len(got) != len(entries) {
		t.Fatalf("len = %d, want %d", len(got), len(entries))
	}
	for i, want := range entries {
		if got[i] != want {
			t.Errorf("entry[%d] = %+v, want %+v", i, got[i], want)
		}
	}
}

func TestReadIndex_Empty(t *testing.T) {
	dir := t.TempDir()
	entries, err := shelf.ReadIndex(dir)
	if err != nil {
		t.Fatalf("ReadIndex on empty dir: %v", err)
	}
	if len(entries) != 0 {
		t.Errorf("expected empty, got %d entries", len(entries))
	}
}

func TestAddAndRemoveEntry(t *testing.T) {
	dir := t.TempDir()
	e := shelf.Entry{Path: "foo.txt", PersonalBlob: "aaaa", BaseBlob: "bbbb", Type: shelf.EntryTypeTracked}

	shelf.WriteIndex(dir, []shelf.Entry{})
	entries, _ := shelf.ReadIndex(dir)
	entries = shelf.AddEntry(entries, e)
	shelf.WriteIndex(dir, entries)

	got, _ := shelf.ReadIndex(dir)
	if len(got) != 1 || got[0] != e {
		t.Errorf("after add: %+v", got)
	}

	got = shelf.RemoveEntry(got, "foo.txt")
	if len(got) != 0 {
		t.Errorf("after remove: %+v", got)
	}
}

func TestFindEntry(t *testing.T) {
	entries := []shelf.Entry{
		{Path: "a.txt", PersonalBlob: "111", Type: shelf.EntryTypeTracked},
		{Path: "b.txt", PersonalBlob: "222", Type: shelf.EntryTypeTracked},
	}
	e, ok := shelf.FindEntry(entries, "b.txt")
	if !ok || e.PersonalBlob != "222" {
		t.Errorf("FindEntry: %+v, %v", e, ok)
	}
	_, ok = shelf.FindEntry(entries, "missing.txt")
	if ok {
		t.Error("expected not found for missing.txt")
	}
}
