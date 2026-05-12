package shelf_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/jwill824/git-shelf/internal/shelf"
)

func TestInstallHooks(t *testing.T) {
	repo := setupRepo(t)

	if err := shelf.InstallHooks(repo.GitDir); err != nil {
		t.Fatalf("InstallHooks: %v", err)
	}

	for _, hookName := range []string{"post-checkout", "post-merge", "post-rewrite"} {
		path := filepath.Join(repo.GitDir, "hooks", hookName)
		info, err := os.Stat(path)
		if err != nil {
			t.Errorf("hook %s not found: %v", hookName, err)
			continue
		}
		if info.Mode()&0111 == 0 {
			t.Errorf("hook %s not executable", hookName)
		}
	}
}

func TestInstallHooks_Idempotent(t *testing.T) {
	repo := setupRepo(t)
	if err := shelf.InstallHooks(repo.GitDir); err != nil {
		t.Fatalf("first install: %v", err)
	}
	if err := shelf.InstallHooks(repo.GitDir); err != nil {
		t.Fatalf("second install: %v", err)
	}
}

func TestUninstallHooks(t *testing.T) {
	repo := setupRepo(t)
	shelf.InstallHooks(repo.GitDir)

	if err := shelf.UninstallHooks(repo.GitDir); err != nil {
		t.Fatalf("UninstallHooks: %v", err)
	}
	for _, hookName := range []string{"post-checkout", "post-merge", "post-rewrite"} {
		path := filepath.Join(repo.GitDir, "hooks", hookName)
		if _, err := os.Stat(path); !os.IsNotExist(err) {
			t.Errorf("hook %s still exists after uninstall", hookName)
		}
	}
}
