package main

func FocusedMonitorDTO(s Snapshot) (MonitorDTO, bool)

func CurrentLocalSlot(s Snapshot, monitorName string, monitorID int) int
func ExistingLocalSlots(s Snapshot, monitorName string, monitorID int) []int
func LocalSlotExists(s Snapshot, monitorName string, monitorID, slot int) bool
func MaxLocalSlot(s Snapshot, monitorName string, monitorID int) int
func LastOccupiedLocalSlot(s Snapshot, monitorName string, monitorID int) int
func ActiveWorkspaceClientCount(s Snapshot) int
func ClientAddressesInWorkspace(s Snapshot, workspaceID int) []string

// Name to dispatch to (prefer plain numeric-on-monitor; else wrapped).
func TargetWorkspaceName(s Snapshot, monitorName string, monitorID, slot int) string
