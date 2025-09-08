package main

import (
	"fmt"
	"sort"
	"strconv"
)

func GetFocusedMonitor(monitors []MonitorDTO, activeWorkspace WorkspaceDTO) (MonitorDTO, bool) {
	if len(monitors) == 1 {
		return monitors[0], true
	}

	// Trust Hyprland's focused flag
	for _, monitor := range monitors {
		if monitor.Focused {
			return monitor, true
		}
	}

	// If, for some reason, Hyprland focused flag is not being updated or doesn't exist,
	// return the monitor that hosts the active workspace.
	if activeWorkspace.Monitor != "" {
		for _, monitor := range monitors {
			if monitor.Name == activeWorkspace.Monitor {
				return monitor, true
			}
		}
	}

	return MonitorDTO{}, false
}

func GetSortedLocalWorkspaces(workspaces []WorkspaceDTO, monitorID int) ([]WorkspaceDTO, error) {
	type tmpWorkspaceDTO struct {
		workspace      WorkspaceDTO
		workspaceIndex int
	}

	tmp := make([]tmpWorkspaceDTO, 0, len(workspaces))
	for _, workspace := range workspaces {
		if workspace.MonitorID != monitorID {
			continue
		}
		workspaceIndex, err := ParseLocalWorkspace(workspace.Name)
		if err != nil {
			return nil, err
		}

		tmp = append(tmp, tmpWorkspaceDTO{workspace, workspaceIndex})
	}
	sort.Slice(tmp, func(i, j int) bool {
		return tmp[i].workspaceIndex < tmp[j].workspaceIndex
	})

	result := make([]WorkspaceDTO, len(tmp))
	for i := range tmp {
		result[i] = tmp[i].workspace
	}

	return result, nil
}

func ActiveLocalIndex(localWorkspaces []WorkspaceDTO, active WorkspaceDTO) (int, error) {
	activeSlot, err := ParseLocalWorkspace(active.Name)
	if err != nil {
		return -1, err
	}

	for i, w := range localWorkspaces {
		s, err := ParseLocalWorkspace(w.Name)
		if err != nil {
			return -1, err
		}
		if s == activeSlot {
			return i, nil
		}
	}

	return -1, nil
}

func LastOccupiedLocalIndex(localWorkspaces []WorkspaceDTO) int {
	last := -1
	for i, w := range localWorkspaces {
		if w.Windows > 0 {
			last = i
		}
	}

	return last
}

func LastExistingLocalWorkspace(localWorkspaces []WorkspaceDTO) int {
	if len(localWorkspaces) == 0 {
		return -1
	}

	return len(localWorkspaces) - 1
}

// DecideTargetIndex returns (targetIdx, noOp).
// 0-based indexes; creation is signaled by targetIdx == len(locals).
func DecideTargetIndex(requested int, locals []WorkspaceDTO, curIdx int) (int, bool) {
	if requested < 0 {
		return 0, true
	}

	lastOcc := LastOccupiedLocalIndex(locals) // -1 if none
	boundary := lastOcc + 1

	// We allow at most:
	// - focus up to boundary (which may be an existing empty index)
	// - and, if boundary == len(locals), allow creation at exactly len(locals)
	maxAllowedIndex := boundary
	if maxAllowedIndex > len(locals) { // should only be == or <, but safe
		maxAllowedIndex = len(locals)
	}

	// Clamp
	target := requested
	if target > maxAllowedIndex {
		target = maxAllowedIndex
	}
	if target < 0 {
		target = 0
	}

	// empty-upward guard: don't move up from an empty current
	if curIdx >= 0 && target > curIdx && locals[curIdx].Windows == 0 {
		return 0, true
	}

	// same index -> no-op
	if curIdx >= 0 && target == curIdx {
		return target, true
	}

	return target, false
}

func TargetNameForSlot(monitorID, slot int) string {
	return zeroWidthToken(monitorID) + strconv.Itoa(slot)
}

// CalculateTargetWorkspaceName returns the canonical name for the target index.
// If targetIndex == len(localWorkspaces), it means "create next" → last slot + 1.
// Requires monitorID for suffix naming.
func CalculateTargetWorkspaceName(localWorkspaces []WorkspaceDTO, targetIndex, monitorID int) (string, error) {
	if len(localWorkspaces) == 0 {
		return TargetNameForSlot(monitorID, 1), nil
	}

	if targetIndex >= len(localWorkspaces) {
		lastSlot, err := ParseLocalWorkspace(localWorkspaces[len(localWorkspaces)-1].Name)
		if err != nil {
			return "", fmt.Errorf("parse last local workspace: %w", err)
		}

		return TargetNameForSlot(monitorID, lastSlot+1), nil
	}

	// Existing case
	workspace, err := ParseLocalWorkspace(localWorkspaces[targetIndex].Name)
	if err != nil {
		return "", fmt.Errorf("parse target local workspace: %w", err)
	}

	return TargetNameForSlot(monitorID, workspace), nil
}
