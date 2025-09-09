package main

import "fmt"

func GoToWorkspace(targetWorkspace int) error {
	snapshot, err := TakeSnapshot(MaskGoto)
	if err != nil {
		return fmt.Errorf("error taking snapshot: %w", err)
	}

	monitor, ok := GetFocusedMonitor(snapshot.Monitors, snapshot.ActiveWorkspace)
	if !ok {
		return fmt.Errorf("no focused monitor found")
	}

	workspaces, err := GetSortedLocalWorkspaces(snapshot.Workspaces, monitor.ID)
	if err != nil {
		return fmt.Errorf("error getting sorted local workspaces: %w", err)
	}

	activeLocalIndex, err := ActiveLocalIndex(workspaces, snapshot.ActiveWorkspace)
	if err != nil {
		return fmt.Errorf("error getting active local index: %w", err)
	}

	targetIndex, noop := DecideTargetIndex(targetWorkspace, workspaces, activeLocalIndex)
	if noop {
		return nil
	}

	workspaceName, err := CalculateTargetWorkspaceName(workspaces, targetIndex, monitor.ID)
	if err != nil {
		return fmt.Errorf("error calculating target workspace name: %w", err)
	}

	return Workspace(workspaceName)
}
