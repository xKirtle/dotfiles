package util

import (
	"os"
	"os/exec"
	"syscall"
)

func Exec(bin string, args []string) error {
	return syscall.Exec(bin, args, os.Environ())
}

func FindBinary(bin string) (string, error) {
	return exec.LookPath(bin)
}
