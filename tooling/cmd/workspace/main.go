package main

import (
	"flag"
	"fmt"
)

func main() {
	var (
		slot int
	)

	flag.IntVar(&slot, "slot", 0, "Workspace slot number")
	flag.Parse()

	snapshot, err := TakeSnapshot(MaskGoto)
	if err != nil {
		fmt.Println("Error taking snapshot:", err)
		return
	}

	// 1. Find current active monitor
	// 2. Get all workspaces on that monitor
	// 3. Find the workspace with the given slot number. Return WorkspaceDTO
	// 3.1 If index out of range, clamp to the nearest valid index
	// 4. Switch to that workspace with dispatch operation

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

	targetIndex, noop := DecideTargetIndex(slot, workspaces, activeLocalIndex)
	if noop {
		fmt.Println("No operation needed, already on the target workspace")
		return
	}

	fmt.Println(targetIndex)

	// Next, calculate the target workspace name (with zero-width chars)
	// and dispatch the workspace change with Hyprctl
}
