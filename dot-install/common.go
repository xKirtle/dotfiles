package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func hasBinary(binary string) bool {
	_, err := exec.LookPath(binary)
	return err == nil
}

func mustHaveBinary(binary string) {
	if !hasBinary(binary) {
		log.Fatalf("Binary %s not found in PATH", binary)
	}
}

func mustFindAurHelper() string {
	knownHelpers := []string{"paru", "yay"} // Maybe others can be added, but I never used them

	for _, helper := range knownHelpers {
		if hasBinary(helper) {
			return helper
		}
	}

	log.Fatalf("No AUR helper found. Supported helpers are: %v", knownHelpers)
	return "" // Unreachable
}

func parseDepsFile(depsFilePath string) ([]string, error) {
	file, err := os.Open(depsFilePath)
	if err != nil {
		return nil, err
	}

	defer func(file *os.File) {
		err := file.Close()
		if err != nil {
			log.Fatalf("failed to close file: %v", err)
		}
	}(file)

	var deps []string
	scanner := bufio.NewScanner(file)

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") || strings.HasPrefix(line, "//") {
			continue
		}

		deps = append(deps, line)
	}

	if err := scanner.Err(); err != nil {
		return nil, err
	}

	return deps, nil
}

func writeFile(filepath string, content []byte) error {
	if filepath == "" {
		return fmt.Errorf("file path is empty")
	}

	err := os.WriteFile(filepath, content, 0o644)
	if err != nil {
		return fmt.Errorf("failed to write file %q: %v", filepath, err)
	}

	return nil
}

func getRepoDir() string {
	mustHaveBinary("git")
	var repoDir string
	cmd := exec.Command("git", "rev-parse", "--show-toplevel")

	if out, err := cmd.Output(); err != nil {
		log.Fatalf("Failed to run 'git rev-parse --show-toplevel': %v", err)
	} else {
		repoDir = strings.TrimSpace(string(out))
	}

	return repoDir
}

func joinHome(path string) (string, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("failed to get user home directory: %w", err)
	}

	return filepath.Join(homeDir, path), nil
}

func pathExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func isSymlink(path string) bool {
	info, err := os.Lstat(path)
	if err != nil {
		return false
	}

	return info.Mode()&os.ModeSymlink != 0
}

func isDirectory(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}

	return info.IsDir()
}

func ensureDirectory(path string) error {
	if pathExists(path) {
		if !isDirectory(path) {
			return fmt.Errorf("path exists and is not a directory: %s", path)
		}

		return nil
	}

	return os.MkdirAll(path, 0755) // rwx|r-x|r-x
}

func removePath(path string) error {
	if !pathExists(path) {
		return nil
	}

	return os.RemoveAll(path)
}

func ensureLink(sourcePath, targetPath string, simulate bool) error {
	// Sanity check that source exists
	if !pathExists(sourcePath) && !isSymlink(sourcePath) {
		return fmt.Errorf("source does not exist: %s", sourcePath)
	}

	// If already the correct symlink, skip
	if isSymlink(targetPath) {
		if dest, err := os.Readlink(targetPath); err == nil && dest == sourcePath {
			fmt.Printf("Already linked: %s -> %s (skipping)\n", targetPath, sourcePath)
			return nil
		}
	}

	// Remove any existing target (including broken symlink)
	if pathExists(targetPath) || isSymlink(targetPath) {
		if simulate {
			fmt.Printf("[Simulate] Removing: %s\n", targetPath)
		} else {
			fmt.Printf("Removing: %s\n", targetPath)
			if err := removePath(targetPath); err != nil {
				return fmt.Errorf("remove %s: %w", targetPath, err)
			}
		}
	}

	// Ensure parent dir exists
	parent := filepath.Dir(targetPath)
	if simulate {
		fmt.Printf("[Simulate] Ensure dir: %s\n", parent)
		fmt.Printf("[Simulate] Linking: %s -> %s\n", targetPath, sourcePath)
		return nil
	}

	if err := ensureDirectory(parent); err != nil {
		return fmt.Errorf("ensure parent %s: %w", parent, err)
	}

	fmt.Printf("Linking: %s -> %s\n", targetPath, sourcePath)
	if err := os.Symlink(sourcePath, targetPath); err != nil {
		return fmt.Errorf("symlink %s -> %s: %w", targetPath, sourcePath, err)
	}
	return nil
}

// Uses os.ReadFile -> os.WriteFile. Not efficient for large file.
func copyFile(sourcePath, targetPath string, simulate bool) error {
	if sourcePath == "" || targetPath == "" {
		return fmt.Errorf("copyFile: empty path (sourcePath=%q, targetPath=%q)", sourcePath, targetPath)
	}

	// Stat source and ensure it's a regular file
	si, err := os.Stat(sourcePath)
	if err != nil {
		return fmt.Errorf("stat source %q: %w", sourcePath, err)
	}

	if !si.Mode().IsRegular() {
		return fmt.Errorf("source is not a regular file: %s", sourcePath)
	}

	// Prevent accidental self-copy
	sourceAbs, _ := filepath.Abs(sourcePath)
	targetAbs, _ := filepath.Abs(targetPath)
	if sourceAbs == targetAbs {
		return fmt.Errorf("source and target are the same: %s", sourcePath)
	}

	// Ensure destination directory exists
	if err := os.MkdirAll(filepath.Dir(targetPath), 0o755); err != nil {
		return fmt.Errorf("create target dir: %w", err)
	}

	if simulate {
		fmt.Printf("[simulate] Copy %s -> %s (mode %o)\n", sourcePath, targetPath, si.Mode().Perm())
		return nil
	}

	data, err := os.ReadFile(sourcePath)
	if err != nil {
		return fmt.Errorf("read source %q: %w", sourcePath, err)
	}

	if err := os.WriteFile(targetPath, data, si.Mode().Perm()); err != nil {
		return fmt.Errorf("write target %q: %w", targetPath, err)
	}

	fmt.Printf("Copied %s -> %s\n", sourcePath, targetPath)
	return nil
}
