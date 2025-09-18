package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
)

const AURHelper = "paru"
const AURDepsFile = "aur-deps"
const FlatpakDepsFile = "flatpak-deps"

func main() {
	var (
		dotfiles    bool
		depsAur     bool
		depsFlatpak bool
		all         bool
		simulate    bool

		exportAur     bool
		exportFlatpak bool
	)

	flag.BoolVar(&dotfiles, "dotfiles", false, "Install dotfiles")
	flag.BoolVar(&depsAur, "aur", false, "Install AUR dependencies")
	flag.BoolVar(&depsFlatpak, "flatpak", false, "Install Flatpak dependencies")
	flag.BoolVar(&all, "all", false, "Install everything")
	flag.BoolVar(&simulate, "simulate", false, "Simulate the installation without making any changes")

	flag.BoolVar(&exportAur, "aur-export", false, "Export AUR dependencies")
	flag.BoolVar(&exportFlatpak, "flatpak-export", false, "Export Flatpak dependencies")
	flag.Parse()

	installRequested := dotfiles || depsAur || depsFlatpak || all
	exportRequested := exportAur || exportFlatpak

	if installRequested && exportRequested {
		log.Fatalf("Cannot export dependencies and install at the same time")
	}

	if installRequested && !(dotfiles || depsAur || depsFlatpak || all) {
		flag.Usage()
		os.Exit(2)
	}

	doAur := depsAur || all
	doFlatpak := depsFlatpak || all
	doDotfiles := dotfiles || all
	repoDir := getRepoDir()

	if doAur {
		mustHaveBinary(AURHelper)
		aurDepsPath := filepath.Join(repoDir, AURDepsFile)
		if err := installAurDeps(aurDepsPath, simulate); err != nil {
			log.Fatalf("Failed to install AUR dependencies: %v", err)
		}

		fmt.Println()
	}

	if doFlatpak {
		mustHaveBinary("flatpak")
		flatpakDepsPath := filepath.Join(repoDir, FlatpakDepsFile)
		if err := installFlatpakDeps(flatpakDepsPath, simulate); err != nil {
			log.Fatalf("Failed to install Flatpak dependencies: %v", err)
		}

		fmt.Println()
	}

	if doDotfiles {
		if err := installDotfiles(repoDir, simulate); err != nil {
			log.Fatalf("Failed to install dotfiles: %v", err)
		}

		fmt.Println()
	}

	if exportAur {
		mustHaveBinary(AURHelper)
		aurDepsPath := filepath.Join(repoDir, AURDepsFile)
		args := []string{"-Qqe"}

		if err := exportGenericDeps(AURHelper, args, aurDepsPath); err != nil {
			log.Fatalf("Failed to export AUR dependencies: %v", err)
		}
	}

	if exportFlatpak {
		mustHaveBinary("flatpak")
		flatpakDepsPath := filepath.Join(repoDir, FlatpakDepsFile)
		args := []string{"list", "--app", "--columns=application"}

		if err := exportGenericDeps("flatpak", args, flatpakDepsPath); err != nil {
			log.Fatalf("Failed to export Flatpak dependencies: %v", err)
		}
	}
}
