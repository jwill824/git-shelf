package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "git-shelf",
	Short: "Personal file overlay manager for git",
	Long:  "Shelf specific files at your personal version, persistent across branch switches.",
}

func init() {
	rootCmd.AddCommand(initCmd, addCmd, addBranchCmd, removeCmd, listCmd, diffCmd, syncCmd, promoteCmd, hookCmd)
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
