package util

import (
	"bytes"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"

	"golang.org/x/sys/unix"
)

// FindBinary looks for the given binary in PATH and returns its full path.
func FindBinary(bin string) (string, error) {
	return exec.LookPath(bin)
}

// HasBinary checks if the given binary is available in PATH.
func HasBinary(bin string) bool {
	_, err := FindBinary(bin)
	return err == nil
}

// MustHaveBinary checks if the given binary is available in PATH and fatals if not.
func MustHaveBinary(bin string) {
	if !HasBinary(bin) {
		Fatalf(ExitNotFound, "required binary not found in PATH: %s", bin)
	}
}

func findPIDsByName(name string) ([]int, error) {
	entries, err := os.ReadDir("/proc")
	if err != nil {
		return nil, err
	}

	target := filepath.Base(name) // normalize
	var pids []int

	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		pidStr := e.Name()
		pid, err := strconv.Atoi(pidStr)
		if err != nil {
			continue // skip non-PIDs
		}

		// Try /proc/<pid>/comm (exact, short name)
		if b, err := os.ReadFile(filepath.Join("/proc", pidStr, "comm")); err == nil {
			comm := strings.TrimSpace(string(b))
			if comm == target {
				pids = append(pids, pid)
				continue
			}
		}

		// Try /proc/<pid>/cmdline (argv[0] basename)
		if b, err := os.ReadFile(filepath.Join("/proc", pidStr, "cmdline")); err == nil && len(b) > 0 {
			// cmdline is NUL-separated; trim the trailing NUL then split
			b = bytes.TrimRight(b, "\x00")
			argv := bytes.Split(b, []byte{0})
			if len(argv) > 0 {
				argv0 := filepath.Base(string(argv[0]))
				if argv0 == target {
					pids = append(pids, pid)
					continue
				}
			}
		}

		// Fallback to /proc/<pid>/exe symlink basename
		if exe, err := os.Readlink(filepath.Join("/proc", pidStr, "exe")); err == nil {
			if filepath.Base(exe) == target {
				pids = append(pids, pid)
				continue
			}
		}
	}

	sort.Ints(pids)
	return pids, nil
}

// IsProcessRunningByName checks if a process with the given name is running.
//   - If name <= 15 chars: checks against /proc/<pid>/comm (fast, exact match).
//   - If name > 15 chars: falls back to /proc/<pid>/cmdline (full command line).
//
// Avoids relying on external commands like pgrep, which may not be available.
func IsProcessRunningByName(name string) bool {
	pids, err := findPIDsByName(name)
	if err != nil {
		return false
	}

	return len(pids) > 0
}

// KillProcessByName is a convenience wrapper around KillPIDs.
func KillProcessByName(name string, timeout time.Duration, force bool) (int, int, error) {
	pids, err := findPIDsByName(name) // your hybrid comm/cmdline finder
	if err != nil {
		return 0, 0, err
	}

	term, kill := KillPIDs(pids, timeout, force)
	return term, kill, nil
}

// KillPIDs sends SIGTERM to the given PIDs, waits up to timeout for exit,
// and if force==true, SIGKILLs any survivors at the end.
// Returns (terminatedOrGone, killedAfterTimeout).
func KillPIDs(pids []int, timeout time.Duration, force bool) (int, int) {
	if len(pids) == 0 {
		return 0, 0
	}
	self := os.Getpid()

	// First pass: TERM
	termCount := 0
	for _, pid := range pids {
		if pid == self {
			continue
		}

		if err := syscall.Kill(pid, syscall.SIGTERM); err == nil || errors.Is(err, syscall.ESRCH) {
			termCount++
		}
	}

	// Wait up to timeout
	deadline := time.Now().Add(timeout)
	alive := make([]int, 0, len(pids))
	for {
		alive = alive[:0]
		for _, pid := range pids {
			if pid == self {
				continue
			}

			if err := syscall.Kill(pid, 0); err == nil {
				alive = append(alive, pid)
			}
		}
		if len(alive) == 0 || time.Now().After(deadline) {
			break
		}

		time.Sleep(100 * time.Millisecond)
	}

	// if forced, KILL pass
	killed := 0
	if force && len(alive) > 0 {
		for _, pid := range alive {
			if err := syscall.Kill(pid, syscall.SIGKILL); err == nil || errors.Is(err, syscall.ESRCH) {
				killed++
			}
		}
	}

	return termCount, killed
}

// IMPROVEMENT: SignalByName should only signal processes owned by the current user.

// SignalByName sends the given signal to all processes matching the given name.
// It ignores "no such process" errors, so it's safe to call even if no such
// process is running.
func SignalByName(name string, sig unix.Signal) error {
	pids, err := findPIDsByName(name)
	if err != nil {
		return err
	}

	for _, pid := range pids {
		if e := unix.Kill(pid, sig); e != nil && !errors.Is(e, unix.ESRCH) {
			return e
		}
	}

	return nil
}
