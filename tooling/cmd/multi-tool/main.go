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
	fmt.Printf(`Usage: multi-tool <command> [args...]

Commands:
  nm-applet             Toggles the NetworkManager applet in the system tray
  power <action>        Perform a power action (exit, lock, reboot, shutdown, suspend, hibernate)
  wlogout               Launch the logout menu
  open-dotfiles         Open the dotfiles directory in VSCode
  clip-history [d|w]    Show clipboard history menu (d: delete entry, w: wipe all entries, no arg: copy entry to clipboard)

`)
}
