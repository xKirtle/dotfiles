package main

type MonitorDTO struct {
	ID          int
	Name        string
	Description string
	Focused     bool
}
type WorkspaceDTO struct {
	ID      int
	Name    string
	Monitor string
}
type ClientDTO struct {
	Address   string
	Workspace int
}
type Snapshot struct {
	Monitors   []MonitorDTO
	Workspaces []WorkspaceDTO
	Clients    []ClientDTO
	ActiveWS   WorkspaceDTO
	ActiveWin  *ClientDTO // nil unless needed (MoveOne)
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
