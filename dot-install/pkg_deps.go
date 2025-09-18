package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
)

func installAurDeps(depsFilePath string, simulate bool) error {
	aurHelper := mustFindAurHelper()
	deps, err := parseDepsFile(depsFilePath)
	if err != nil {
		return fmt.Errorf("failed to parse aur deps: %v", err)
	}

	if len(deps) == 0 {
		log.Printf("no aur dependencies found in %s", depsFilePath)
		return nil
	}

	args := []string{
		"-S", "--needed", "--noconfirm",
		"--noprovides", "--useask", "--batchinstall",
		"--norebuild", "--sudoloop", "--skipreview",
	}

	if simulate {
		args = append(args, "--print")
		log.Printf("[Simulate] Installing %d AUR dependencies using %s. [%s..%s]",
			len(deps), aurHelper, deps[0], deps[len(deps)-1])

		return nil
	} else {
		args = append(args, deps...)
	}

	log.Printf("Installing %d AUR dependencies using %s. [%s..%s]",
		len(deps), aurHelper, deps[0], deps[len(deps)-1])

	cmd := exec.Command(aurHelper, args...)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr

	if err := cmd.Run(); err != nil {
		return err
	}

	return nil
}

func installFlatpakDeps(depsFilePath string, simulate bool) error {
	mustHaveBinary("flatpak")
	deps, err := parseDepsFile(depsFilePath)
	if err != nil {
		return fmt.Errorf("failed to parse flatpak deps: %v", err)
	}

	if len(deps) == 0 {
		log.Printf("no flatpak dependencies found")
		return nil
	}

	if simulate {
		log.Printf("[Simulate] Installing %d Flatpak dependencies. [%s..%s]",
			len(deps), deps[0], deps[len(deps)-1])

		return nil
	}

	for _, dep := range deps {
		cmd := exec.Command(dep, "install", "-y", "flathub", dep)
		cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr

		log.Printf("Installing Flatpak dependency: %s", dep)
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("failed to install flatpak dependency %s: %v", dep, err)
		}
	}

	return nil
}

func exportGenericDeps(binary string, args []string, depsFilePath string) error {
	mustHaveBinary(binary)
	cmd := exec.Command(binary, args...)
	cmd.Stderr = os.Stderr
	out, err := cmd.Output()

	if err != nil {
		return fmt.Errorf("failed to export dependencies using %s: %v", binary, err)
	}

	if err := writeFile(depsFilePath, out); err != nil {
		return fmt.Errorf("failed to write dependencies to file: %v", err)
	}

	return nil
}
