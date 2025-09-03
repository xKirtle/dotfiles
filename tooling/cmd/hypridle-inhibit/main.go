package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

// Router-style main: dispatch to subcommands based on flags.
func main() {
	var (
		fDaemon  = flag.Bool("daemon", false, "Run background reconciliation loop")
		fToggle  = flag.Bool("toggle", false, "Toggle manual override")
		fEnable  = flag.Bool("enable", false, "Set override to enabled")
		fDisable = flag.Bool("disable", false, "Set override to disabled")
		fStatus  = flag.Bool("status", false, "Print Waybar JSON status")
	)
	flag.Parse()

	execMap := map[string]func(){
		"daemon":  cmdDaemon,
		"toggle":  cmdToggle,
		"enable":  cmdEnable,
		"disable": cmdDisable,
		"status":  cmdStatus,
	}

	selFlag := selectFlag(map[string]bool{
		"daemon":  *fDaemon,
		"toggle":  *fToggle,
		"enable":  *fEnable,
		"disable": *fDisable,
		"status":  *fStatus,
	})

	if selFlag == "" {
		flag.PrintDefaults()
	}

	if valueFunc, keyExists := execMap[selFlag]; keyExists {
		valueFunc()
		return
	}
}

// selectFlag returns true if exactly one flag in the map is true.
// If more than one is true, it prints an error and exits.
// If none are true, it returns the empty string.
func selectFlag(m map[string]bool) string {
	chosen := ""
	for flagName, flagValue := range m {
		if flagValue {
			if chosen != "" {
				_, _ = fmt.Fprintf(os.Stderr, "error: flags --%s and --%s are mutually exclusive\n", chosen, flagName)
				os.Exit(util.ExitMissingArgs)
			}

			chosen = flagName
		}
	}

	return chosen
}
