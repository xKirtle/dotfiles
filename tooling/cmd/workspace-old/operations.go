package main

// Goto: choose target slot from index with guard/boundary logic.
func DecideTargetGoto(snapshot Snapshot, monitorID int, index int) (slot int, noop bool) {
	if index <= 0 {
		return 0, true
	}

	existingSlots := ExistingLocalSlots(snapshot, monitorID)
	currentSlot := CurrentLocalSlot(snapshot, monitorID)
	lastOccupiedSlot := LastOccupiedLocalSlot(snapshot, monitorID)
	maxSlot := MaxLocalSlot(snapshot, monitorID)
	activeCount := ActiveWorkspaceClientCount(snapshot)

	// N-th existing local slot
	if idx := index - 1; idx >= 0 && idx < len(existingSlots) {
		target := existingSlots[idx]
		if target == currentSlot {
			return 0, true // already there
		}

		// Empty upward move guard
		if activeCount == 0 && target > currentSlot && currentSlot > 0 {
			return 0, true
		}

		return target, false
	}

	// Boundary creation
	var boundary int
	if lastOccupiedSlot == 0 {
		if maxSlot == 0 {
			boundary = 1 // first-ever workspace
		} else {
			boundary = maxSlot + 1 // next after max
		}
	} else {
		boundary = lastOccupiedSlot + 1 // next after last occupied
	}

	if activeCount == 0 && boundary > currentSlot && currentSlot > 0 {
		return 0, true
	}

	if boundary < 1 {
		boundary = 1
	}

	return boundary, false
}

// // Move: like goto, but blocks upward moves that would empty the source.
// func DecideTargetMove(snapshot Snapshot, monitorName string, monitorID, index int, mode MoveMode, srcWorkspaceID int) (slot int, noop bool)
//
// // Cycle: next/prev among existing with wrap and same guard behavior.
// func DecideCycleTarget(snapshot Snapshot, monitorName string, monitorID int, direction string) (slot int, noop bool)
