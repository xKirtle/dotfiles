package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

func main() {
	var (
		doDotfiles    = flag.Bool("dotfiles", false, "install dotfiles")
		doDepsAur     = flag.Bool("deps-aur", false, "install AUR/pacman dependencies from manifest")
		doDepsFlatpak = flag.Bool("deps-flatpak", false, "install Flatpak dependencies from manifest")
		doAll         = flag.Bool("all", false, "run deps-aur, deps-flatpak, then dotfiles")
		simulate      = flag.Bool("simulate", false, "simulate dotfiles installation (no changes)")
	)
	flag.Parse()

	if !*doDotfiles && !*doDepsAur && !*doDepsFlatpak && !*doAll {
		flag.PrintDefaults()
		os.Exit(util.ExitMissingArgs)
	}

	runAur := *doDepsAur || *doAll
	runFlatpak := *doDepsFlatpak || *doAll
	runDotfiles := *doDotfiles || *doAll

	util.MustHaveBinary("git")
	repoDirByteArray, _ := util.MustRunWith("git", []string{"rev-parse", "--show-toplevel"}, util.CaptureOutput())
	repoDir := strings.TrimSpace(string(repoDirByteArray))

	if runAur {
		aurDepsManifest := filepath.Join(repoDir, "/aur-deps.txt")
		err := installAurDeps(aurDepsManifest, false)

		if err != nil {
			fmt.Printf("Failed to install AUR/pacman dependencies: %v", err)
			return
		}
	}

	if runFlatpak {
		flatpakDepsManifest := filepath.Join(repoDir, "/flatpak-deps.txt")
		err := installFlatpakDeps(flatpakDepsManifest, false)

		if err != nil {
			fmt.Printf("Failed to install Flatpak dependencies: %v", err)
			return
		}
	}

	if runDotfiles {
		installDotfiles(repoDir, *simulate)
	}
}
