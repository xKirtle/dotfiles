package main

import (
	"fmt"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
	"golang.org/x/sys/unix"
)

func RunInstallUpdates(opts InstallOptions) {
	util.ClearScreen()

	if !opts.NoBanner {
		util.PrintHeaderBanner("AUR Updates")
		fmt.Println()
	}

	if !opts.AssumeYes {
		promptStartUpdate()
	} else {
		util.Prefix("Starting the update...")
	}

	aurHelper := util.DetectPackageManager()
	util.Prefix(fmt.Sprintf("Detected AUR helper: \u001b[34m%s\u001b[0m", aurHelper))

	// Run AUR/system update
	util.MustRunWith(aurHelper, nil, util.Interactive())

	fmt.Println()

	// Flatpak (optional)
	if !opts.NoFlatpak && util.HasBinary("flatpak") {
		util.Prefix("Searching for Flatpak updates...")
		util.MustRunWith("flatpak", []string{"update", "-y"}, util.Interactive())
		fmt.Println()
	}

	// Reload Waybar (best-effort)
	if util.HasBinary("pkill") {
		util.Prefix("Restarting Waybar...")
		const SIGRTMIN1 = unix.Signal(35) // usually SIGRTMIN+1
		_ = util.SignalByName("waybar", SIGRTMIN1)
	}

	util.Prefix("Update process complete! Press [ENTER] to close.")
	_, _ = fmt.Scanln()
}

func promptStartUpdate() {
	util.MustHaveBinary("gum")
	_, code := util.MustRunWith("gum", []string{"confirm", "DO YOU WANT TO START THE UPDATE NOW?"}, util.Interactive())

	switch code {
	case util.ExitSuccess:
		// proceed
	case util.ExitInterrupted:
		util.Fatalf(util.ExitInterrupted, "\u001B[34m::\u001B[0m Update cancelled by user")
	case util.ExitFailure:
		util.Fatalf(util.ExitFailure, "\u001B[34m::\u001B[0m Update declined by user")
	default:
		util.Fatalf(code, "gum exited with code %d", code)
	}
}
