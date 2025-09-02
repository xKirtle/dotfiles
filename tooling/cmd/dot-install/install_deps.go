package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

// installAurDeps installs AUR/pacman packages listed in a file (one per line).
// Lines starting with '#' or empty lines are ignored.
func installAurDeps(manifestPath string, interactive bool) error {
	packages, err := readPackagesList(manifestPath)
	if err != nil {
		return err
	}
	if len(packages) == 0 {
		util.Prefix("AUR deps manifest is empty — nothing to do.")
		return nil
	}

	helper := util.DetectPackageManager()
	util.Prefix(fmt.Sprintf("Installing %d package(s) via %s…", len(packages), helper))

	args := []string{"-S", "--needed"}
	if !interactive {
		args = append(args, "--noconfirm")
	}
	args = append(args, packages...)

	// Let output stream to the terminal (prompts, progress, errors).
	code, runErr := util.RunInteractive(helper, args...)
	if runErr != nil {
		util.CheckExec(runErr, "running %s %v", helper, packages)
	}
	if code != 0 {
		return fmt.Errorf("%s exited with code %d", helper, code)
	}
	return nil
}

func readPackagesList(path string) ([]string, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("open manifest: %w", err)
	}
	defer func() { _ = f.Close() }()

	var out []string
	seen := make(map[string]struct{})
	sc := bufio.NewScanner(f)
	// allow long lines just in case
	buf := make([]byte, 0, 1<<20)
	sc.Buffer(buf, 1<<20)

	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if _, ok := seen[line]; ok {
			continue
		}
		seen[line] = struct{}{}
		out = append(out, line)
	}
	if err := sc.Err(); err != nil {
		return nil, fmt.Errorf("read manifest: %w", err)
	}
	return out, nil
}

// installFlatpakDeps installs Flatpak apps listed in manifestPath (one App ID per line).
// Lines starting with '#' and blanks are ignored.
func installFlatpakDeps(manifestPath string, interactive bool) error {
	// Read package list
	packages, err := readPackagesList(manifestPath) // your existing helper; returns []string
	if err != nil {
		return err
	}
	if len(packages) == 0 {
		util.Prefix("Flatpak manifest is empty — nothing to install.")
		return nil
	}

	// Ensure flatpak is available
	if !util.HasBinary("flatpak") {
		return fmt.Errorf("flatpak not found on PATH")
	}

	// Ensure the flathub remote exists
	ensureFlathub := func() error {
		out, _, _ := util.RunCommand("flatpak", "remote-list", "--columns=name")
		has := false
		for _, line := range strings.Split(out, "\n") {
			if strings.TrimSpace(line) == "flathub" {
				has = true
				break
			}
		}
		if has {
			return nil
		}
		util.Prefix("Adding Flathub remote…")
		code, runErr := util.RunInteractive("flatpak", "remote-add", "--if-not-exists",
			"flathub", "https://flathub.org/repo/flathub.flatpakrepo")
		if runErr != nil {
			return runErr
		}
		if code != 0 {
			return fmt.Errorf("flatpak remote-add exited with code %d", code)
		}
		return nil
	}
	if err := ensureFlathub(); err != nil {
		return err
	}

	// Install
	for _, app := range packages {
		args := []string{"install"}
		if !interactive {
			args = append(args, "-y")
		}
		args = append(args, "flathub", app)

		util.Prefix("Installing " + app + "…")
		code, runErr := util.RunInteractive("flatpak", args...)
		if runErr != nil {
			fmt.Printf("flatpak install %s failed: %v\n", app, runErr)
			continue
		}
		if code != 0 {
			fmt.Printf("flatpak install %s exited with %d\n", app, code)
			continue
		}
	}

	return nil
}
