package util

import (
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
)

const (
	ExitSuccess     = 0   // Successful execution
	ExitFailure     = 1   // General failure
	ExitMissingArgs = 2   // Not enough arguments provided
	ExitNotFound    = 127 // Command not found
	ExitInterrupted = 130 // Script terminated by Control-C
)

// Fatalf prints a message and exits with the given code
func Fatalf(code int, format string, args ...any) {
	log.SetFlags(0)
	log.Printf(format, args...)
	os.Exit(code)
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
		msg := fmt.Sprintf(context, args...)
		Fatalf(ExitNotFound, "%s: %v", msg, err)
	default:
		msg := fmt.Sprintf(context, args...)
		Fatalf(ExitFailure, "%s: %v", msg, err)
	}
}
