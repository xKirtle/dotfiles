package util

import (
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
)

const (
	ExitSuccess       = 0   // Successful execution
	ExitFailure       = 1   // General failure
	ExitNotExecutable = 126 // Command invoked cannot execute
	ExitNotFound      = 127 // Command not found
)

// Fatalf prints a message and exits with the given code
func Fatalf(code int, format string, args ...any) {
	log.SetFlags(0)
	log.Printf(format, args...)
	os.Exit(code)
}

// Check exits with ExitFailure if err != nil
func Check(err error) {
	if err != nil {
		Fatalf(ExitFailure, "%v", err)
	}
}

// Checkf adds context and exits if err != nil
func Checkf(err error, format string, args ...any) {
	if err == nil {
		return
	}
	msg := fmt.Sprintf(format, args...)
	Fatalf(ExitFailure, "%s: %v", msg, err)
}

// CheckExec maps common exec errors to shell-like exit codes
func CheckExec(err error, context string, args ...any) {
	if err == nil {
		return
	}

	switch {
	case errors.Is(err, exec.ErrNotFound):
		Fatalf(ExitNotFound, context+": %v", append(args, err)...)
	default:
		Fatalf(ExitFailure, context+": %v", append(args, err)...)
	}
}
