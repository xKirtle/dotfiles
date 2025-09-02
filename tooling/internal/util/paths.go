package util

import (
	"fmt"
	"os"
	"path/filepath"
)

// HomeDir returns the current user's home directory
// It first tries os.UserHomeDir, then falls back to the HOME environment variable
// If neither method works, it fatals
func HomeDir() string {
	if home, err := os.UserHomeDir(); err == nil && home != "" {
		return home
	}

	if home := os.Getenv("HOME"); home != "" {
		return home
	}

	Fatalf(ExitFailure, "Could not determine home directory: HOME not set and os.UserHomeDir failed")
	return "" // unreachable
}

// JoinHome joins a relative path to the home directory
func JoinHome(rel string) string {
	return filepath.Join(HomeDir(), rel)
}

// PathExists checks if a path exists
func PathExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// IsSymlink checks if the given path is a symbolic link
func IsSymlink(path string) bool {
	info, err := os.Lstat(path)
	if err != nil {
		return false
	}

	return info.Mode()&os.ModeSymlink != 0
}

// IsDirectory checks if the given path is a directory
func IsDirectory(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}

	return info.IsDir()
}

// EnsureDirectory ensures that a directory exists at the given path
// If the path exists and is not a directory, it returns an error
// If the directory does not exist, it creates it with 0755 permissions
func EnsureDirectory(path string) error {
	if PathExists(path) {
		if !IsDirectory(path) {
			return fmt.Errorf("path exists and is not a directory: %s", path)
		}
		return nil // Directory already exists
	}

	return os.MkdirAll(path, 0755) // rwx|r-x|r-x
}

// RemovePath removes the file or directory at the given path
// If the path does not exist, it does nothing and returns nil
// If the path exists, it removes it and all its contents if it's a directory
func RemovePath(path string) error {
	if !PathExists(path) {
		return nil // Nothing to do
	}

	return os.RemoveAll(path)
}
