package shelf

import (
	"fmt"
	"os"
	"path/filepath"
)

var hookNames = []string{"post-checkout", "post-merge", "post-rewrite"}

// hookScript is installed into .git/hooks/<name>. It calls git-shelf hook <type>.
func hookScript(hookType string) string {
	return fmt.Sprintf("#!/bin/sh\nexec git-shelf hook %s \"$@\"\n", hookType)
}

// InstallHooks writes git-shelf hook scripts into .git/hooks/.
// Safe to call multiple times — overwrites existing git-shelf hooks.
func InstallHooks(gitDir string) error {
	hooksDir := filepath.Join(gitDir, "hooks")
	if err := os.MkdirAll(hooksDir, 0755); err != nil {
		return fmt.Errorf("mkdir hooks: %w", err)
	}
	for _, name := range hookNames {
		path := filepath.Join(hooksDir, name)
		if err := os.WriteFile(path, []byte(hookScript(name)), 0755); err != nil {
			return fmt.Errorf("write hook %s: %w", name, err)
		}
	}
	return nil
}

// UninstallHooks removes git-shelf hook scripts from .git/hooks/.
func UninstallHooks(gitDir string) error {
	hooksDir := filepath.Join(gitDir, "hooks")
	for _, name := range hookNames {
		path := filepath.Join(hooksDir, name)
		if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
			return fmt.Errorf("remove hook %s: %w", name, err)
		}
	}
	return nil
}
