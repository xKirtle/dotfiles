package main

import (
	"fmt"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
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
	util.MustRunInteractive(aurHelper)
	fmt.Println()

	// Flatpak (optional)
	if !opts.NoFlatpak && util.HasBinary("flatpak") {
		util.Prefix("Searching for Flatpak updates...")
		util.MustRunInteractive("flatpak", "update", "-y")
		fmt.Println()
	}

	// Reload Waybar (best-effort)
	if util.HasBinary("pkill") {
		util.Prefix("Restarting Waybar...")
		_, _ = util.RunInteractive("pkill", "-RTMIN+1", "waybar")
	}

	util.Prefix("Update process complete! Press [ENTER] to close.")
	_, _ = fmt.Scanln()
}

func promptStartUpdate() {
	gum := util.MustHaveBinary("gum")
	code, err := util.RunInteractive(gum, "confirm", "DO YOU WANT TO START THE UPDATE NOW?")
	if err != nil {
		util.CheckExec(err, "launching gum confirm")
	}

	switch code {
	case util.ExitSuccess:
		// proceed
	case util.ExitInterrupted:
		util.Fatalf(util.ExitInterrupted, "\u001B[34m::\u001B[0m Update cancelled by user")
	case util.ExitFailure:
		util.Fatalf(util.ExitFailure, "\u001B[34m::\u001B[0m Update declined by user")
	default:
		util.Fatalf(code, "%s exited with code %d", gum, code)
	}
}
