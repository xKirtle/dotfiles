package main

import (
	"fmt"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

func detectPackageManager() string {
	helpers := []string{"paru", "yay", "pikaur", "trizen", "aurman", "pacaur", "pakku"}

	for _, h := range helpers {
		if util.HasBinary(h) {
			return h
		}
	}
	util.Fatalf(util.ExitFailure, "No AUR helper found. Supported helpers are: %v", helpers)
	return "" // unreachable
}

func printHeaderBanner(text string) {
	if util.HasBinary("figlet") {
		util.MustRunInteractive("figlet", "-f", "smslant", text)
	} else {
		fmt.Printf("==== %s ====\n", text)
	}
}

func prefix(msg string) {
	const (
		blue  = "\u001b[34m"
		reset = "\u001b[0m"
	)
	fmt.Printf("%s%s%s %s\n", blue, "::", reset, msg)
}
