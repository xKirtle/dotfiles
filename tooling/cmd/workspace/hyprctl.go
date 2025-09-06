package main

import (
	"fmt"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

type Hyprctl struct{}

func runHypr(args ...string) error {
	_, status, err := util.Run("hyprctl", args...)
	if err != nil {
		return err
	}

	if status != 0 {
		return fmt.Errorf("hyprctl %v exited with status %d", args, status)
	}

	return nil
}

func (h *Hyprctl) Workspace(name string) error {
	return runHypr("dispatch", "workspace", "name:"+name)
}

func (h *Hyprctl) MoveWorkspaceToMonitor(name, monitorName string) error {
	return runHypr("dispatch", "moveworkspacetomonitor", "name:"+name, monitorName)
}

func (h *Hyprctl) RenameWorkspace(from, to string) error {
	return runHypr("dispatch", "renameworkspace", "name:"+from, to)
}

func (h *Hyprctl) MoveToWorkspaceSilent(targetName, windowAddr string) error {
	// name:...,address:... must be a single argument
	arg := fmt.Sprintf("name:%s,address:%s", targetName, windowAddr)
	return runHypr("dispatch", "movetoworkspacesilent", arg)
}

func (h *Hyprctl) KillWorkspace(numeric string) error {
	return runHypr("dispatch", "killworkspace", numeric)
}
