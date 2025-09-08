package main

import (
	"flag"
	"fmt"
)

func main() {
	var (
		targetWorkspace int
	)

	flag.IntVar(&targetWorkspace, "targetWorkspace", 0, "Workspace index to switch to [1-9]")
	flag.Parse()
	targetWorkspace = targetWorkspace - 1 // Convert to 0-based index for easier calculations

	snapshot, err := TakeSnapshot(MaskGoto)
	if err != nil {
		fmt.Println("Error taking snapshot:", err)
		return
	}

	monitor, ok := GetFocusedMonitor(snapshot.Monitors, snapshot.ActiveWorkspace)
	if !ok {
		fmt.Println("No focused monitor found")
		return
	}

	workspaces, err := GetSortedLocalWorkspaces(snapshot.Workspaces, monitor.ID)
	if err != nil {
		fmt.Println("Error getting sorted local workspaces:", err)
		return
	}

	activeLocalIndex, err := ActiveLocalIndex(workspaces, snapshot.ActiveWorkspace)
	if err != nil {
		fmt.Println("Error getting active local index:", err)
		return
	}

	targetIndex, noop := DecideTargetIndex(targetWorkspace, workspaces, activeLocalIndex)
	if noop {
		fmt.Println("No operation needed, already on the target workspace")
		return
	}

	workspaceName, err := CalculateTargetWorkspaceName(workspaces, targetIndex, monitor.ID)
	if err != nil {
		fmt.Println("Error calculating target workspace name:", err)
		return
	}

	_ = Workspace(workspaceName)
}
