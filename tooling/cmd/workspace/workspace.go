package main

import (
	"sort"
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

// DecideTargetIndex given requested 0-based index.
//   - boundaryIdx = lastOccIdx + 1
//   - targetIdx = clamp(requested, 0 .. min(boundaryIdx, len(locals)))
//     (allow exactly len(locals) to mean “create next” when boundary permits)
//   - no-op if current is empty and targetIdx > curIdx
//
// Returns (targetIdx, ok). ok=false => no-op.
func DecideTargetIndex(requested int, localWorkspaces []WorkspaceDTO, curIndex int) (int, bool) {
	if requested < 0 {
		return 0, true
	}
	lastOcc := LastOccupiedLocalIndex(localWorkspaces) // -1 if none
	boundary := lastOcc + 1                            // 0 if none occupied

	// Max allowed existing index to *focus* is min(boundary, len(localWorkspaces)-1).
	// We also allow target == len(localWorkspaces) to signal “create next” if boundary >= len(localWorkspaces).
	maxExistingIdx := len(localWorkspaces) - 1
	if boundary-1 < maxExistingIdx {
		maxExistingIdx = boundary - 1
	}

	allowCreate := boundary >= len(localWorkspaces)

	// Clamp
	target := requested
	if target > maxExistingIdx {
		if allowCreate && target == len(localWorkspaces) {
			// ok: creation position
		} else {
			// clamp down to max we’re allowed to focus
			target = maxExistingIdx
		}
	}
	if target < 0 {
		target = 0
	}

	// empty-upward guard
	if curIndex >= 0 && target > curIndex && localWorkspaces[curIndex].Windows == 0 {
		return 0, true
	}
	// same index -> no-op
	if curIndex >= 0 && target == curIndex {
		return 0, true
	}
	return target, false
}
