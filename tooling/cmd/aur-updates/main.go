package main

import (
	"fmt"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

// Doesn't update Flatpaks if something goes wrong with AUR updates. Don't really care though.
func main() {
	util.ClearScreen()
	printHeaderBanner("AUR Updates")

	aurHelper := detectPackageManager()
	prefix("Detected AUR helper: \u001b[34m" + aurHelper + "\u001b[0m\n")

	promptStartUpdate()
	util.MustRunInteractive(aurHelper)
	fmt.Println()

	if util.HasBinary("flatpak") {
		prefix("Searching for Flatpak updates...")
		util.MustRunInteractive("flatpak", "update", "-y")
		fmt.Println()
	}

	if util.HasBinary("pkill") {
		prefix("Restarting Waybar...")
		_, _ = util.RunInteractive("pkill", "-RTMIN+1", "waybar")
	}

	prefix("Update process complete! Press [ENTER] to close.")
	_, _ = fmt.Scanln() // wait for enter

}

func printHeaderBanner(text string) {
	if util.HasBinary("figlet") {
		util.MustRunInteractive("figlet", "-f", "smslant", text)
	} else {
		fmt.Printf("==== %s ====\n", text)
	}

	fmt.Println()
}

func promptStartUpdate() {
	gum := util.MustHaveBinary("gum")
	code := util.MustRunInteractive(gum, "confirm", "DO YOU WANT TO START THE UPDATE NOW?")

	switch code {
	case 0:
		// user confirmed
		prefix("Starting the update...")
	case 130:
		// user cancelled (CTRL+C)
		util.Fatalf(130, ":: Update cancelled by user")
	case 1:
		// user declined
		util.Fatalf(1, ":: Update declined by user")
	default:
		// an error occurred
		util.Fatalf(code, "%s exited with code %d", gum, code)
	}
}

func detectPackageManager() string {
	// Check if any known (non-graphical) pacman wrappers are installed in order of preference with pacman last as a fallback
	helpers := []string{"paru", "yay", "pikaur", "trizen", "aurman", "pacaur", "pakku"}

	// Return the first one found
	for _, helper := range helpers {
		if util.HasBinary(helper) {
			return helper
		}
	}

	// If none are found, exit with an error
	util.Fatalf(1, "No AUR helper found. Supported helpers are: %v", helpers)
	return "" // Unreachable, but required to satisfy the compiler
}

func prefix(msg string) {
	const blue = "\u001b[34m"
	const reset = "\u001b[0m"

	fmt.Printf("%s%s%s %s\n", blue, "::", reset, msg)
}
