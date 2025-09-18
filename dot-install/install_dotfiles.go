package main

import (
	"fmt"
	"os"
	"path/filepath"
)

func installDotfiles(repoDir string, simulate bool) error {
	fmt.Println("Installing dotfiles...")
	fmt.Printf("Dotfiles Path: %s\n", repoDir)
	fmt.Printf("Simulation Mode: %v\n", simulate)

	if err := installDotConfig(repoDir, simulate); err != nil {
		return fmt.Errorf("failed to install dot config: %w", err)
	}

	return nil
}

func installDotConfig(repoDir string, simulate bool) error {
	targetDir, err := joinHome(".config")
	if err != nil {
		return fmt.Errorf("failed to get home .config directory: %w", err)
	}

	if err := ensureDirectory(targetDir); err != nil {
		return fmt.Errorf("failed to ensure ~/.config directory exists: %w", err)
	}

	sourceDir := filepath.Join(repoDir, ".config")
	fmt.Printf("Linking config files from %s to %s\n", sourceDir, targetDir)

	if !isDirectory(sourceDir) {
		return fmt.Errorf("source .config directory does not exist in the repository: %s", sourceDir)
	}

	configs, err := os.ReadDir(sourceDir)
	if err != nil {
		return fmt.Errorf("failed to read source .config directory: %w", err)
	}

	for _, entry := range configs {
		name := entry.Name()

		err := linkConfigEntry(name, sourceDir, targetDir, simulate)
		if err != nil {
			return fmt.Errorf("failed to link config entry %s: %w", name, err)
		}
	}

	return nil
}

func linkConfigEntry(name, sourceDir, targetDir string, simulate bool) error {
	// Exceptions that should be copied instead of symlinked
	exceptions := map[string]struct{}{
		"mimeapps.list": {},
	}

	sourcePath := filepath.Join(sourceDir, name)
	targetPath := filepath.Join(targetDir, name)

	if _, isException := exceptions[name]; isException {
		// Copy instead of link, then stop.
		if err := copyFile(sourcePath, targetPath, simulate); err != nil {
			return fmt.Errorf("copy exception %q: %w", name, err)
		}

		return nil
	}

	// Otherwise, create/update the symlink
	if err := ensureLink(sourcePath, targetPath, simulate); err != nil {
		return fmt.Errorf("symlink %q -> %q: %w", sourcePath, targetPath, err)
	}

	return nil
}
