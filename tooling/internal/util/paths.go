package util

import (
	"fmt"
	"os"
	"path/filepath"
)

// HomeDir returns the user's home directory using os.UserHomeDir() with $HOME fallback.
func HomeDir() (string, error) {
	if h, err := os.UserHomeDir(); err == nil && h != "" {
		return h, nil
	}
	h := os.Getenv("HOME")
	if h == "" {
		return "", fmt.Errorf("HOME not set")
	}
	return h, nil
}

// JoinHome joins a relative path to the home directory.
func JoinHome(rel string) (string, error) {
	home, err := HomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, rel), nil
}
