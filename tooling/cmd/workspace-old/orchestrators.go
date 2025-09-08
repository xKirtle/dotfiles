package main

//
// func GotoByIndex(s Snapshot, d Dispatcher, monitorName string, monitorID, index int) (changed bool, err error)
// func MoveToIndex(s Snapshot, d Dispatcher, monitorName string, monitorID, index int, mode MoveMode) (changed bool, err error)
// func CycleLocalWorkspace(s Snapshot, d Dispatcher, monitorName string, monitorID int, direction string) (changed bool, err error)
// func GotoLocalSlot(s Snapshot, d Dispatcher, monitorName string, monitorID, slot int) (changed bool, err error)
//
// // Init helpers
// func EnsureSlotOnMonitor(s Snapshot, d Dispatcher, monitorName string, monitorID, slot int) error
// func InitLocalSlot1(s Snapshot, d Dispatcher, descA, descB string) error
// func MonitorByDescription(s Snapshot, desc string) (MonitorDTO, bool)
