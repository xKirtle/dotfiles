package runx

import (
	"context"
	"os"
	"os/exec"
)

func Run(ctx context.Context, cmd string, args ...string) error {
	c := exec.CommandContext(ctx, cmd, args...)
	c.Stdout, c.Stderr, c.Stdin = os.Stdout, os.Stderr, os.Stdin
	return c.Run()
}

func Sh(ctx context.Context, script string) error {
	c := exec.CommandContext(ctx, "bash", "-lc", script)
	c.Stdout, c.Stderr, c.Stdin = os.Stdout, os.Stderr, os.Stdin
	return c.Run()
}
