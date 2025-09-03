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
		nmApplet(args)
	case "power":
		power(args)
	case "wlogout":
		wlogout()
	default:
		fmt.Printf("Unknown command: %s\n\n", cmd)
		printUsage()
		os.Exit(util.ExitMissingArgs)
	}
}

func printUsage() {

}
