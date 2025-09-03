package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

func installDotfiles(repoDir string, simulate bool) {
	util.PrintHeaderBanner("Install Dotfiles")
	fmt.Println()

	util.Prefix(fmt.Sprintf("Dotfiles Path: \u001b[34m%s\u001b[0m", repoDir))
	util.Prefix(fmt.Sprintf("Simulation Mode: \u001b[34m%t\u001b[0m", simulate))
	fmt.Println()

	installConfigs(repoDir, simulate)
	installIcons(repoDir, simulate)
}

func installConfigs(repoDir string, simulate bool) {
	homeConfig := util.JoinHome(".config")
	err := util.EnsureDirectory(homeConfig)
	util.Check(err, "Failed to ensure directory: %s", homeConfig)

	util.Prefix("Processing .config subfolders...")
	repoConfig := filepath.Join(repoDir, ".config")

	if !util.IsDirectory(repoConfig) {
		fmt.Println("No .config directory found in the repository (skipping)")
		return
	}

	entries, err := os.ReadDir(repoConfig)
	util.Check(err, "Failed to read directory: %s", repoConfig)

	for _, entry := range entries {
		name := entry.Name()
		sourcePath := filepath.Join(repoConfig, name)
		targetPath := filepath.Join(homeConfig, name)

		err := ensureLink(targetPath, sourcePath, simulate)
		util.Check(err, "Failed to link %s -> %s", sourcePath, targetPath)
	}

	fmt.Println()
}

func installIcons(repoDir string, simulate bool) {
	repoIcons := filepath.Join(repoDir, ".icons")
	if !util.IsDirectory(repoIcons) {
		fmt.Println("No .icons directory found in the repository (skipping)")
		return
	}

	util.Prefix("Processing .icons...")
	homeIcons := util.JoinHome(".icons")

	err := ensureLink(homeIcons, repoIcons, simulate)
	util.Check(err, "Failed to link %s -> %s", repoIcons, homeIcons)

	fmt.Println()
}
