package main

type FetchMask uint8

const (
	FMonitors FetchMask = 1 << iota
	FWorkspaces
	FClients
	FActiveWS
	FActiveWin
)

func (mask FetchMask) Has(flag FetchMask) bool {
	return mask&flag != 0
}

func (mask FetchMask) Add(flag FetchMask) FetchMask {
	return mask | flag
}

func (mask FetchMask) Remove(flag FetchMask) FetchMask {
	return mask &^ flag
}

// TODO: Maybe not needed?
func NewMask(flags ...FetchMask) FetchMask {
	var mask FetchMask
	for _, flag := range flags {
		mask |= flag
	}

	return mask
}

const (
	// For "workspace goto N"
	MaskGoto = FWorkspaces | FClients | FActiveWS | FMonitors

	// For "workspace move one N"
	MaskMoveOne = FWorkspaces | FClients | FActiveWS | FActiveWin

	// For "workspace move all N"
	MaskMoveAll = FWorkspaces | FClients | FActiveWS

	// For "workspace cycle up|down"
	MaskCycle = FWorkspaces | FClients | FActiveWS

	// For "workspace init"
	MaskInit = FMonitors | FWorkspaces | FClients
)
