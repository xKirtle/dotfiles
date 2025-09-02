package util

import (
	"bytes"
	"errors"
	"os"
	"os/exec"
	"syscall"
)

// Exec replaces the current process (handoff)
func Exec(bin string, args ...string) error {
	return syscall.Exec(bin, append([]string{bin}, args...), os.Environ())
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

// MustHaveBinary is the fatal-on-failure wrapper for FindBinary
func MustHaveBinary(bin string) string {
	path, err := FindBinary(bin)
	if err != nil {
		CheckExec(err, "finding binary %s", bin)
	}

	return path
}

// RunCommand runs a command and captures stdout+stderr.
// Returns (output, exitCode, error):
//   - output: combined stdout+stderr
//   - exitCode: 0 if success, non-zero if program failed, -1 if could not start
//   - err: non-nil only if the process could not be started at all
func RunCommand(bin string, args ...string) (string, int, error) {
	cmd := exec.Command(bin, args...)

	var buf bytes.Buffer
	cmd.Stdout = &buf
	cmd.Stderr = &buf

	err := cmd.Run()
	output := buf.String()

	if err == nil {
		return output, 0, nil
	}

	var ee *exec.ExitError
	if errors.As(err, &ee) {
		return output, ee.ExitCode(), nil
	}

	return output, -1, err
}

// MustRunCommand is the fatal-on-failure wrapper for RunCommand.
func MustRunCommand(bin string, args ...string) (string, int) {
	out, code, err := RunCommand(bin, args...)
	if err != nil {
		CheckExec(err, "running %s %v", bin, args)
	}
	return out, code
}

// RunInteractive runs a command with stdin/stdout/stderr bound to the current process.
// Returns (exitCode, error):
//   - exitCode: 0 if success, non-zero if program failed, -1 if could not start
//   - err: non-nil only if the process could not be started at all
func RunInteractive(bin string, args ...string) (int, error) {
	cmd := exec.Command(bin, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	err := cmd.Run()
	if err == nil {
		return 0, nil
	}

	var ee *exec.ExitError
	if errors.As(err, &ee) {
		return ee.ExitCode(), nil
	}

	return -1, err
}

// MustRunInteractive is the fatal-on-failure wrapper for RunInteractive.
func MustRunInteractive(bin string, args ...string) int {
	code, err := RunInteractive(bin, args...)
	if err != nil {
		CheckExec(err, "running %s %v", bin, args)
	}
	return code
}
