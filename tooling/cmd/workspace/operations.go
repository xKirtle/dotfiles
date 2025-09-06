package main

// Goto: choose target slot from index with guard/boundary logic.
func DecideTargetGoto(s Snapshot, monitorName string, monitorID, index int) (slot int, noop bool)

// Move: like goto, but blocks upward moves that would empty the source.
func DecideTargetMove(s Snapshot, monitorName string, monitorID, index int, mode MoveMode, srcWorkspaceID int) (slot int, noop bool)

// Cycle: next/prev among existing with wrap and same guard behavior.
func DecideCycleTarget(s Snapshot, monitorName string, monitorID int, direction string) (slot int, noop bool)
