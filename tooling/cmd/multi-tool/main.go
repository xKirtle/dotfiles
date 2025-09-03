package main

import (
	"fmt"
	"os"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(util.ExitMissingArgs)
	}

	cmd := os.Args[1]
	args := os.Args[2:]

	switch cmd {
	case "nm-applet":
		nmApplet()
	case "power":
		power(args)
	case "wlogout":
		wlogout()
	case "open-dotfiles":
		openDotfiles()
	case "clip-history":
		clipboardHistory(args)
	default:
		fmt.Printf("Unknown command: %s\n\n", cmd)
		printUsage()
		os.Exit(util.ExitMissingArgs)
	}
}

func printUsage() {
	fmt.Printf(`Usage: %s <command> [args...]

Commands:
  nm-applet       Launch NetworkManager applet (nm-applet)
  power <action>  Perform a power action (exit, lock, reboot, shutdown, suspend, hibernate)
  wlogout        Launch the logout menu (wlogout)
`, os.Args[0])
}
