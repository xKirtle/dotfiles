package main

import (
	"errors"
	"flag"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

func main() {
	subcmd, subArgs, err := splitSubcommand(os.Args)
	if err != nil {
		fail(err)
	}

	switch subcmd {
	case "goto":
		targetIdx, err := parseGotoArgs(subArgs)
		if err != nil {
			fail(err)
		}

		_ = GoToWorkspace(targetIdx)

	case "move":
		targetIdx, all, err := parseMoveArgs(subArgs)
		if err != nil {
			fail(err)
		}

		// runMove(by, all)
		_, _ = targetIdx, all // placeholder to avoid unused variable error

	case "cycle":
		dir, err := parseCycleArgs(subArgs)
		if err != nil {
			fail(err)
		}

		// runCycle(dir)
		_ = dir // placeholder to avoid unused variable error

	case "help", "-h", "--help", "":
		printRootUsage()

	default:
		fail(fmt.Errorf("unknown subcommand: %q", subcmd))
	}
}

func parseGotoArgs(args []string) (int, error) {
	if len(args) != 1 {
		return 0, errors.New("usage: mytool goto <1..9>")
	}

	v, err := strconv.Atoi(args[0])
	if err != nil || v < 1 || v > 9 {
		return 0, errors.New("goto index must be a digit 1..9")
	}

	return v, nil
}

func parseMoveArgs(args []string) (int, bool, error) {
	fs := flag.NewFlagSet("move", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)
	all := fs.Bool("all", false, "Apply to all")

	// Separate flags from non-flag args
	if err := fs.Parse(args); err != nil {
		return 0, false, err
	}

	// After parsing, any leftover args are positional
	pos := fs.Args()
	if len(pos) != 1 {
		return 0, false, errors.New("usage: workspace move <1..9> [--all]")
	}

	v, err := strconv.Atoi(pos[0])
	if err != nil {
		return 0, false, errors.New("move expects an integer digit")
	}

	return v, *all, nil
}

func parseCycleArgs(args []string) (string, error) {
	if len(args) != 1 {
		return "", errors.New("usage: workspace cycle <up|down>")
	}

	val := strings.ToLower(args[0])
	if val != "up" && val != "down" {
		return "", errors.New("cycle direction must be 'up' or 'down'")
	}

	return val, nil
}

func splitSubcommand(argv []string) (string, []string, error) {
	if len(argv) < 2 {
		return "", nil, nil
	}

	return argv[1], argv[2:], nil
}

func printRootUsage() {
	_, _ = fmt.Fprintln(os.Stderr, `Usage:
  workspace goto  <1..9>
  workspace move  <1..9> [--all]
  workspace cycle <up|down>`)
}

func fail(err error) {
	_, _ = fmt.Fprintln(os.Stderr, "Error:", err)
	printRootUsage()
	os.Exit(util.ExitMissingArgs)
}
