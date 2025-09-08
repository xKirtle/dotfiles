package main

import (
	"sort"
	"strconv"
)

func FocusedMonitorDTO(snapshot Snapshot) (MonitorDTO, bool) {
	if len(snapshot.Monitors) == 1 {
		return snapshot.Monitors[0], true
	}

	// Trust Hyprland's focused flag
	for _, monitor := range snapshot.Monitors {
		if monitor.Focused {
			return monitor, true
		}
	}

	// If, for some reason, Hyprland focused flag is not being updated or doesn't exist,
	// return the monitor that hosts the active workspace.
	if snapshot.ActiveWorkspace.Monitor != "" {
		for _, monitor := range snapshot.Monitors {
			if monitor.Name == snapshot.ActiveWorkspace.Monitor {
				return monitor, true
			}
		}
	}

	return MonitorDTO{}, false
}

func CurrentLocalSlot(snapshot Snapshot, monitorID int) int {
	// Try to find active workspace on the specified monitor first
	for _, monitor := range snapshot.Monitors {
		if monitor.ID == monitorID {
			if monitor.ActiveWorkspace.Name != "" {
				return ParseLocalSlot(monitor.ActiveWorkspace.Name, monitorID)
			}

			break
		}
	}

	// Fallback: if the global active workspace is on the specified monitor, use it
	if snapshot.ActiveWorkspace.MonitorID == monitorID && snapshot.ActiveWorkspace.Name != "" {
		return ParseLocalSlot(snapshot.ActiveWorkspace.Name, monitorID)
	}

	return 0
}

func ExistingLocalSlots(snapshot Snapshot, monitorID int) []int {
	var slots = make([]int, 0)
	for _, workspace := range snapshot.Workspaces {
		if workspace.MonitorID == monitorID {
			slots = append(slots, ParseLocalSlot(workspace.Name, monitorID))
		}
	}

	sort.Ints(slots)

	// Deduplicate
	j := 0
	for i := 0; i < len(slots); i++ {
		if i == 0 || slots[i] != slots[i-1] {
			slots[j] = slots[i]
			j++
		}
	}

	return slots[:j]
}

func LocalSlotExists(snapshot Snapshot, monitorID, slot int) bool {
	if slot <= 0 {
		return false
	}

	for _, workspace := range snapshot.Workspaces {
		if workspace.MonitorID != monitorID {
			continue
		}

		slotInt, err := strconv.Atoi(workspace.Name)
		if err != nil {
			continue
		}

		if slotInt == slot {
			return true
		}
	}

	return false
}

func MaxLocalSlot(snapshot Snapshot, monitorID int) int {
	slots := ExistingLocalSlots(snapshot, monitorID)
	if len(slots) == 0 {
		return 0
	}

	return slots[len(slots)-1] // slots is sorted
}

func LastOccupiedLocalSlot(snapshot Snapshot, monitorID int) int {
	maxSlot := 0
	for _, workspace := range snapshot.Workspaces {
		if workspace.MonitorID != monitorID || workspace.Windows == 0 {
			continue
		}

		slotInt, err := strconv.Atoi(workspace.Name)
		if err != nil {
			continue
		}

		if slotInt > maxSlot {
			maxSlot = slotInt
		}
	}

	return maxSlot
}

func ActiveWorkspaceClientCount(snapshot Snapshot) int {
	return snapshot.ActiveWorkspace.Windows
}

func ClientAddressesInWorkspace(snapshot Snapshot, workspaceID int) []string {
	addresses := make([]string, 0)
	for _, client := range snapshot.Clients {
		if client.Workspace.ID == workspaceID {
			addresses = append(addresses, client.Address)
		}
	}

	return addresses
}
