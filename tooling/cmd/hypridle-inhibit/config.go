package main

import (
	"os"
	"path/filepath"
	"time"
)

const (
	checkEvery = time.Second
)

// overrideFile path (XDG_RUNTIME_DIR or /tmp)
func overrideFile() string {
	runtimeDir := os.Getenv("XDG_RUNTIME_DIR")
	if runtimeDir == "" {
		runtimeDir = "/tmp"
	}

	return filepath.Join(runtimeDir, "hypridle.override")
}

// lockFile path (XDG_RUNTIME_DIR or /tmp)
func lockFile() string {
	runtimeDir := os.Getenv("XDG_RUNTIME_DIR")
	if runtimeDir == "" {
		runtimeDir = "/tmp"
	}

	return filepath.Join(runtimeDir, "hypridle-inhibit.lock")
}
