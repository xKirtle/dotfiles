package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"time"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

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

func NewMask(flags ...FetchMask) FetchMask {
	var mask FetchMask
	for _, flag := range flags {
		mask |= flag
	}

	return mask
}

// capture a single `-j` query
func hyprJSON(query string) ([]byte, error) {
	args := []string{"-j", query}
	out, status, err := util.RunWith("hyprctl", args, util.CaptureOutput(), util.WithTimeout(2*time.Second))

	if err != nil {
		return nil, err
	}

	if status != 0 {
		return nil, fmt.Errorf("hyprctl -j %s: exit status %d", query, status)
	}

	return out, nil
}

func fetchMonitors() ([]MonitorDTO, error) {
	rawJson, err := hyprJSON("monitors")
	if err != nil {
		return nil, err
	}

	var monitorDTOS []MonitorDTO
	if err := json.Unmarshal(rawJson, &monitorDTOS); err != nil {
		return nil, fmt.Errorf("parse monitors: %w", err)
	}

	return monitorDTOS, nil
}

func fetchWorkspaces() ([]WorkspaceDTO, error) {
	rawJson, err := hyprJSON("workspaces")
	if err != nil {
		return nil, err
	}

	var workspaceDTOS []WorkspaceDTO
	if err := json.Unmarshal(rawJson, &workspaceDTOS); err != nil {
		return nil, fmt.Errorf("parse workspaces: %w", err)
	}

	return workspaceDTOS, nil
}

func fetchClients() ([]ClientDTO, error) {
	rawJson, err := hyprJSON("clients")
	if err != nil {
		return nil, err
	}

	var tmp []struct {
		Address   string `json:"address"`
		Workspace struct {
			ID int `json:"id"`
		} `json:"workspace"`
	}

	if err := json.Unmarshal(rawJson, &tmp); err != nil {
		return nil, fmt.Errorf("parse clients: %w", err)
	}

	clientDTOS := make([]ClientDTO, 0, len(tmp))
	for _, c := range tmp {
		clientDTOS = append(clientDTOS, ClientDTO{Address: c.Address, Workspace: c.Workspace.ID})
	}

	return clientDTOS, nil
}

func fetchActiveWorkspace() (WorkspaceDTO, error) {
	rawJson, err := hyprJSON("activeworkspace")
	if err != nil {
		return WorkspaceDTO{}, err
	}

	if trimmedJson := bytes.TrimSpace(rawJson); len(trimmedJson) == 0 || bytes.Equal(trimmedJson, []byte("null")) {
		return WorkspaceDTO{}, nil
	}

	var workspaceDTO WorkspaceDTO
	if err := json.Unmarshal(rawJson, &workspaceDTO); err != nil {
		return WorkspaceDTO{}, fmt.Errorf("parse activeworkspace: %w", err)
	}

	return workspaceDTO, nil
}

func fetchActiveWindow() (*ClientDTO, error) {
	rawJson, err := hyprJSON("activewindow")
	if err != nil {
		// treat "no active window" as none
		return nil, nil
	}

	if trimmedJson := bytes.TrimSpace(rawJson); len(trimmedJson) == 0 || bytes.Equal(trimmedJson, []byte("null")) {
		return nil, nil
	}

	var tmp struct {
		Address   string `json:"address"`
		Workspace struct {
			ID int `json:"id"`
		} `json:"workspace"`
	}

	if err := json.Unmarshal(rawJson, &tmp); err != nil {
		return nil, fmt.Errorf("parse activewindow: %w", err)
	}

	if tmp.Address == "" && tmp.Workspace.ID == 0 {
		return nil, nil
	}

	clientDTO := &ClientDTO{Address: tmp.Address, Workspace: tmp.Workspace.ID}
	return clientDTO, nil
}

func TakeSnapshot(mask FetchMask) (Snapshot, error) {
	var snapshot Snapshot
	var err error

	if mask.Has(FMonitors) {
		if snapshot.Monitors, err = fetchMonitors(); err != nil {
			return snapshot, err
		}
	}

	if mask.Has(FWorkspaces) {
		if snapshot.Workspaces, err = fetchWorkspaces(); err != nil {
			return snapshot, err
		}
	}

	if mask.Has(FClients) {
		if snapshot.Clients, err = fetchClients(); err != nil {
			return snapshot, err
		}
	}

	if mask.Has(FActiveWS) {
		if snapshot.ActiveWS, err = fetchActiveWorkspace(); err != nil {
			return snapshot, err
		}
	}

	if mask.Has(FActiveWin) {
		if snapshot.ActiveWin, err = fetchActiveWindow(); err != nil {
			return snapshot, err
		}
	}

	return snapshot, nil
}
