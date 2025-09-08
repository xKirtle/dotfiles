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

	fmt.Println(slot)

	snapshot, err := TakeSnapshot(MaskGoto)
	if err != nil {
		fmt.Println("Error taking snapshot:", err)
		return
	}

	slot, noop := DecideTargetGoto(snapshot, 0, 3)
	if noop {
		fmt.Println("No operation needed")
	} else {
		fmt.Printf("Switching to slot %d\n", slot)
	}
}
