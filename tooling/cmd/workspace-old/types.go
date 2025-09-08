package main

type MonitorDTO struct {
	ID              int
	Name            string
	Description     string
	Focused         bool
	ActiveWorkspace struct {
		ID   int
		Name string
	}
}

type WorkspaceDTO struct {
	ID        int
	Name      string
	Monitor   string
	MonitorID int
	Windows   int // number of windows/clients
}

type ClientDTO struct {
	Address   string
	Monitor   int
	Workspace struct {
		ID   int
		Name string
	}
}

type Snapshot struct {
	Monitors        []MonitorDTO
	Workspaces      []WorkspaceDTO
	Clients         []ClientDTO
	ActiveWorkspace WorkspaceDTO
	ActiveWindow    *ClientDTO // nil unless needed (MoveOne)
}

type Dispatcher interface {
	Workspace(name string) error
	MoveWorkspaceToMonitor(name, monitorName string) error
	RenameWorkspace(from, to string) error
	MoveToWorkspaceSilent(targetName, windowAddr string) error
	KillWorkspace(numeric string) error
}

type MoveMode int

const (
	MoveOne MoveMode = iota
	MoveAll
)
