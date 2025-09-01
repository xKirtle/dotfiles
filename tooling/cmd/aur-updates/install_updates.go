package main

import (
	"fmt"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

func RunInstallUpdates(opts InstallOptions) {
	util.ClearScreen()

	if !opts.NoBanner {
		printHeaderBanner("AUR Updates")
		fmt.Println()
	}

	if !opts.AssumeYes {
		promptStartUpdate()
	} else {
		prefix("Starting the update...")
	}

	aurHelper := detectPackageManager()
	prefix(fmt.Sprintf("Detected AUR helper: \u001b[34m%s\u001b[0m", aurHelper))

	// Run AUR/system update
	util.MustRunInteractive(aurHelper)
	fmt.Println()

	// Flatpak (optional)
	if !opts.NoFlatpak && util.HasBinary("flatpak") {
		prefix("Searching for Flatpak updates...")
		util.MustRunInteractive("flatpak", "update", "-y")
		fmt.Println()
	}

	// Reload Waybar (best-effort)
	if util.HasBinary("pkill") {
		prefix("Restarting Waybar...")
		_, _ = util.RunInteractive("pkill", "-RTMIN+1", "waybar")
	}

	prefix("Update process complete! Press [ENTER] to close.")
	_, _ = fmt.Scanln()
}

func promptStartUpdate() {
	gum := util.MustHaveBinary("gum")
	code, err := util.RunInteractive(gum, "confirm", "DO YOU WANT TO START THE UPDATE NOW?")
	if err != nil {
		util.CheckExec(err, "launching gum confirm")
	}

	switch code {
	case 0:
		// proceed
	case 130:
		util.Fatalf(130, "\u001B[34m::\u001B[0m Update cancelled by user")
	case 1:
		util.Fatalf(1, "\u001B[34m::\u001B[0m Update declined by user")
	default:
		util.Fatalf(code, "%s exited with code %d", gum, code)
	}
}
