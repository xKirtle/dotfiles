package util

import (
	"errors"
	"os"
	"os/exec"
	"syscall"
)

// Exec replaces the current process (handoff)
func Exec(bin string, args []string) error {
	return syscall.Exec(bin, args, os.Environ())
}

// FindBinary looks up a binary path in PATH
func FindBinary(bin string) (string, error) {
	return exec.LookPath(bin)
}

// HasBinary checks if a binary exists in PATH
func HasBinary(bin string) bool {
	_, err := FindBinary(bin)
	return err == nil
}

// MustHaveBinary looks up a binary and exits if not found
func MustHaveBinary(bin string) string {
	path, err := FindBinary(bin)
	if err != nil {
		CheckExec(err, "finding binary %s", bin)
	}

	return path
}

// RunInteractive runs a command attached to the current TTY and
// returns (exitCode, err). Non-zero exits are not an error here, they’re
// reported via exitCode. err is only for spawn/exec failures
func RunInteractive(bin string, args ...string) (int, error) {
	cmd := exec.Command(bin, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	err := cmd.Run()
	if err == nil {
		return 0, nil
	}
	var ee *exec.ExitError
	if errors.As(err, &ee) {
		return ee.ExitCode(), nil
	}
	// Could not start the process (binary missing, permission, etc.)
	return -1, err
}

// MustRunInteractive runs a command and returns its exit code.
// If the process cannot be started at all, it exits the current process
// using your existing CheckExec mapping (127 for not found, etc...)
func MustRunInteractive(bin string, args ...string) int {
	code, err := RunInteractive(bin, args...)
	if err != nil {
		CheckExec(err, "running %s %v", bin, args)
	}
	return code
}
