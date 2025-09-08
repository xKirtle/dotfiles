package main

import (
	"fmt"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

func runHyprctl(args ...string) error {
	_, status, err := util.Run("hyprctl", args...)
	if err != nil {
		return err
	}

	if status != 0 {
		return fmt.Errorf("hyprctl %v exited with status %d", args, status)
	}

	return nil
}

func Workspace(name string) error {
	return runHyprctl("dispatch", "workspace", "name:"+name)
}

func MoveWorkspaceToMonitor(name, monitorName string) error {
	return runHyprctl("dispatch", "moveworkspacetomonitor", "name:"+name, monitorName)
}

func RenameWorkspace(from, to string) error {
	return runHyprctl("dispatch", "renameworkspace", "name:"+from, to)
}

func MoveToWorkspaceSilent(targetName, windowAddr string) error {
	// name:...,address:... must be a single argument
	arg := fmt.Sprintf("name:%s,address:%s", targetName, windowAddr)
	return runHyprctl("dispatch", "movetoworkspacesilent", arg)
}

func KillWorkspace(numeric string) error {
	return runHyprctl("dispatch", "killworkspace", numeric)
}
