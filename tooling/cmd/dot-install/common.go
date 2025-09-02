package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

// ensureLink replaces any existing target (file/dir/symlink, even broken) with a symlink to source.
// If the target is already a symlink pointing to source, it does nothing.
// Returns nil on success.
func ensureLink(targetPath, sourcePath string, simulate bool) error {
	// Optional: sanity check that source exists
	if !util.PathExists(sourcePath) && !util.IsSymlink(sourcePath) {
		return fmt.Errorf("source does not exist: %s", sourcePath)
	}

	// If already the correct symlink, skip
	if util.IsSymlink(targetPath) {
		if dest, err := os.Readlink(targetPath); err == nil && dest == sourcePath {
			fmt.Printf("Already linked: %s -> %s (skipping)\n", targetPath, sourcePath)
			return nil
		}
	}

	// Remove any existing target (including broken symlink)
	if util.PathExists(targetPath) || util.IsSymlink(targetPath) {
		if simulate {
			fmt.Printf("[SIMULATE] Removing: %s\n", targetPath)
		} else {
			fmt.Printf("Removing: %s\n", targetPath)
			if err := util.RemovePath(targetPath); err != nil {
				return fmt.Errorf("remove %s: %w", targetPath, err)
			}
		}
	}

	// Ensure parent dir exists
	parent := filepath.Dir(targetPath)
	if simulate {
		fmt.Printf("[SIMULATE] Ensure dir: %s\n", parent)
		fmt.Printf("[SIMULATE] Linking: %s -> %s\n", targetPath, sourcePath)
		return nil
	}

	if err := util.EnsureDirectory(parent); err != nil {
		return fmt.Errorf("ensure parent %s: %w", parent, err)
	}

	fmt.Printf("Linking: %s -> %s\n", targetPath, sourcePath)
	if err := os.Symlink(sourcePath, targetPath); err != nil {
		return fmt.Errorf("symlink %s -> %s: %w", targetPath, sourcePath, err)
	}
	return nil
}
