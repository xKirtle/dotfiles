package main

import (
	"flag"
)

type InstallOptions struct {
	NoBanner  bool
	AssumeYes bool
	NoFlatpak bool
}

type CheckOptions struct {
	EmitJSON        bool
	ThresholdGreen  int
	ThresholdYellow int
	ThresholdRed    int
}

func main() {
	// Modes
	modeInstall := flag.Bool("install", false, "Install updates (AUR helper, optional Flatpak, reload Waybar)")
	modeCheck := flag.Bool("check", false, "Check for updates (default)")

	// Install flags
	noBanner := flag.Bool("no-banner", false, "Do not print figlet banner")
	assumeYes := flag.Bool("y", false, "Assume Yes (skip confirmation)")
	noFlatpak := flag.Bool("no-flatpak", false, "Do not run 'flatpak update'")

	// Check flags
	jsonOut := flag.Bool("json", true, "Emit Waybar JSON output in --check mode")
	thresholdGreen := flag.Int("thr-green", 0, "Threshold for green")
	thresholdYellow := flag.Int("thr-yellow", 25, "Threshold for yellow")
	thresholdRed := flag.Int("thr-red", 100, "Threshold for red")

	flag.Parse()

	// Default to --check
	if !*modeInstall && !*modeCheck {
		*modeCheck = true
	}

	if *modeInstall {
		RunInstallUpdates(InstallOptions{
			NoBanner:  *noBanner,
			AssumeYes: *assumeYes,
			NoFlatpak: *noFlatpak,
		})
		return
	}

	RunFindUpdates(CheckOptions{
		EmitJSON:        *jsonOut,
		ThresholdGreen:  *thresholdGreen,
		ThresholdYellow: *thresholdYellow,
		ThresholdRed:    *thresholdRed,
	})
}
