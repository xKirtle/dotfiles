package util

import (
	"bytes"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
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

// RunCommandWithInput runs a command with the given input string as stdin and captures stdout+stderr
// Returns (output, exitCode, error):
//   - output: combined stdout+stderr
//   - exitCode: 0 if success, non-zero if program failed, -1 if could not start
//   - err: non-nil only if the process could not be started at all
func RunCommandWithInput(input string, bin string, args ...string) (string, int, error) {
	cmd := exec.Command(bin, args...)

	var buf bytes.Buffer
	cmd.Stdout = &buf
	cmd.Stderr = &buf
	cmd.Stdin = strings.NewReader(input)

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

// MustRunCommandWithInput is the fatal-on-failure wrapper for RunCommandWithInput
func MustRunCommandWithInput(input string, bin string, args ...string) (string, int) {
	out, code, err := RunCommandWithInput(input, bin, args...)
	if err != nil {
		CheckExec(err, "running %s %v", bin, args)
	}

	return out, code
}

// RunInteractiveWithInput runs bin/args with stdin=input and inherits stdio.
// If dropStderr is true, stderr goes to /dev/null (useful for wl-copy).
func RunInteractiveWithInput(input string, dropStderr bool, bin string, args ...string) (int, error) {
	cmd := exec.Command(bin, args...)
	cmd.Stdin = strings.NewReader(input)
	cmd.Stdout = os.Stdout

	if dropStderr {
		f, err := os.OpenFile(os.DevNull, os.O_WRONLY, 0)
		if err != nil {
			return -1, err
		}
		defer f.Close()
		cmd.Stderr = f
	} else {
		cmd.Stderr = os.Stderr
	}

	if err := cmd.Run(); err != nil {
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			return ee.ExitCode(), nil
		}
		return -1, err
	}
	return 0, nil
}

// MustRunInteractiveWithInput is the fatal-on-failure variant.
func MustRunInteractiveWithInput(input string, dropStderr bool, bin string, args ...string) int {
	code, err := RunInteractiveWithInput(input, dropStderr, bin, args...)
	if err != nil {
		CheckExec(err, "running %s %v", bin, args)
	}
	return code
}

// RunCommandBytesWithInput is like RunCommandWithInput but uses []byte for input and output.
// Returns (output, exitCode, error):
//   - output: combined stdout+stderr
//   - exitCode: 0 if success, non-zero if program failed, -1 if could not start
//   - err: non-nil only if the process could not be started at all
func RunCommandBytesWithInput(input []byte, bin string, args ...string) ([]byte, int, error) {
	cmd := exec.Command(bin, args...)
	cmd.Stdin = bytes.NewReader(input)
	var buf bytes.Buffer
	cmd.Stdout = &buf
	cmd.Stderr = &buf
	err := cmd.Run()
	if err == nil {
		return buf.Bytes(), 0, nil
	}
	var ee *exec.ExitError
	if errors.As(err, &ee) {
		return buf.Bytes(), ee.ExitCode(), nil
	}
	return buf.Bytes(), -1, err
}

// MustRunCommandBytesWithInput is the fatal-on-failure wrapper for RunCommandBytesWithInput.
func MustRunCommandBytesWithInput(input []byte, bin string, args ...string) ([]byte, int) {
	out, code, err := RunCommandBytesWithInput(input, bin, args...)
	if err != nil {
		CheckExec(err, "running %s %v", bin, args)
	}
	return out, code
}

// RunInteractiveBytesWithInput runs bin/args with stdin=data and inherits stdio.
// If dropStderr is true, stderr goes to /dev/null (helps wl-copy fully detach).
func RunInteractiveBytesWithInput(data []byte, dropStderr bool, bin string, args ...string) (int, error) {
	cmd := exec.Command(bin, args...)
	cmd.Stdin = bytes.NewReader(data)
	cmd.Stdout = os.Stdout

	if dropStderr {
		f, err := os.OpenFile(os.DevNull, os.O_WRONLY, 0)
		if err != nil {
			return -1, err
		}
		defer f.Close()
		cmd.Stderr = f
	} else {
		cmd.Stderr = os.Stderr
	}

	if err := cmd.Run(); err != nil {
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			return ee.ExitCode(), nil
		}
		return -1, err
	}
	return 0, nil
}

// MustRunInteractiveBytesWithInput is the fatal-on-failure variant.
func MustRunInteractiveBytesWithInput(data []byte, dropStderr bool, bin string, args ...string) int {
	code, err := RunInteractiveBytesWithInput(data, dropStderr, bin, args...)
	if err != nil {
		CheckExec(err, "running %s %v", bin, args)
	}
	return code
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

func findPIDsByName(name string) ([]int, error) {
	entries, err := os.ReadDir("/proc")
	if err != nil {
		return nil, err
	}

	useCmdline := len(name) > 15
	var pids []int

	for _, e := range entries {
		if !e.IsDir() {
			continue
		}

		pidStr := e.Name()
		pid, err := strconv.Atoi(pidStr)
		if err != nil {
			continue // skip non-numeric
		}

		if useCmdline {
			data, err := os.ReadFile(filepath.Join("/proc", pidStr, "cmdline"))
			if err != nil || len(data) == 0 {
				continue
			}

			cmdline := strings.ReplaceAll(string(data), "\x00", " ")
			if strings.Contains(cmdline, name) {
				pids = append(pids, pid)
			}
		} else {
			data, err := os.ReadFile(filepath.Join("/proc", pidStr, "comm"))
			if err != nil {
				continue
			}

			comm := strings.TrimSpace(string(data))
			if comm == name {
				pids = append(pids, pid)
			}
		}
	}
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

	// Optional KILL pass
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

// RunCommandDetached starts a command in a new session, detached from the current terminal.
// It redirects stdin, stdout, and stderr to /dev/null to prevent blocking.
// Returns an error if the command could not be started.
func RunCommandDetached(bin string, args ...string) error {
	MustHaveBinary(bin)

	cmd := exec.Command(bin, args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}

	// Redirect stdin, stdout, stderr to /dev/null
	// This prevents the command from blocking if it tries to read from stdin or write to stdout/stderr
	// and the parent process has no terminal attached.
	null, _ := os.OpenFile(os.DevNull, os.O_RDWR, 0)
	cmd.Stdin = null
	cmd.Stdout = null
	cmd.Stderr = null

	return cmd.Start()
}
