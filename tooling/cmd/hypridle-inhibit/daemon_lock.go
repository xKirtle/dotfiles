package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

// Acquire a singleton daemon lock. If stale, remove and retry
func acquireDaemonLock() {
	lockFile := lockFile()
	pid := os.Getpid()

	try := func() error {
		f, err := os.OpenFile(lockFile, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0644)
		if err != nil {
			return err
		}

		defer func() { _ = f.Close() }()
		_, _ = fmt.Fprintf(f, "%d\n", pid)

		return nil
	}

	if err := try(); err == nil {
		return
	}

	// Lock exists, check if recorded PID is our daemon and alive
	if b, err := os.ReadFile(lockFile); err == nil {
		if s := strings.TrimSpace(string(b)); s != "" {
			if lp, err := parsePID(s); err == nil {
				if processIsOurDaemon(lp) {
					_, _ = fmt.Fprintf(os.Stderr, "hypridle-inhibit: another daemon is running (pid %d)\n", lp)
					os.Exit(util.ExitFailure)
				}
			}
		}
	}

	// Stale lock — remove and retry.
	_ = os.Remove(lockFile)
	if err := try(); err != nil {
		_, _ = fmt.Fprintf(os.Stderr, "hypridle-inhibit: failed to create lockfile %s: %v\n", lockFile, err)
		os.Exit(util.ExitFailure)
	}
}

func releaseDaemonLock() { _ = os.Remove(lockFile()) }

func parsePID(s string) (int, error) {
	var n int
	_, err := fmt.Sscanf(s, "%d", &n)

	return n, err
}

// processIsOurDaemon checks if PID corresponds to the hypridle-inhibit binary (avoids PID reuse false-positives)
func processIsOurDaemon(pid int) bool {
	if pid <= 0 {
		return false
	}

	commPath := filepath.Join("/proc", fmt.Sprintf("%d", pid), "comm")
	b, err := os.ReadFile(commPath)
	if err != nil {
		return false
	}

	comm := strings.TrimSpace(string(b))
	return comm == "hypridle-inhibit" || comm == filepath.Base(os.Args[0])
}
