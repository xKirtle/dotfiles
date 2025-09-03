package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

func power(args []string) {
	if len(args) == 0 {
		printPowerUsage()
		os.Exit(util.ExitMissingArgs)
	}

	switch args[0] {
	case "exit":
		util.Prefix("Exit")
		terminateClients(5 * time.Second)
		util.MustHaveBinary("hyprctl")
		util.MustRunInteractive("hyprctl", "dispatch", "exit")

	case "lock":
		util.Prefix("Lock")
		util.MustHaveBinary("hyprlock")
		util.MustRunInteractive("hyprlock")

	case "reboot":
		util.Prefix("Reboot")
		terminateClients(5 * time.Second)
		util.MustHaveBinary("systemctl")
		util.MustRunInteractive("systemctl", "reboot")

	case "shutdown":
		util.Prefix("Shutdown")
		terminateClients(5 * time.Second)
		util.MustHaveBinary("systemctl")
		util.MustRunInteractive("systemctl", "poweroff")

	case "suspend":
		util.Prefix("Suspend")
		util.MustHaveBinary("systemctl")
		util.MustRunInteractive("systemctl", "suspend")

	case "hibernate":
		util.Prefix("Hibernate")
		util.MustHaveBinary("systemctl")
		util.MustRunInteractive("systemctl", "hibernate")

	default:
		fmt.Printf("Unknown power action: %s\n\n", args[0])
		printPowerUsage()
		os.Exit(util.ExitMissingArgs)
	}
}

func printPowerUsage() {
	fmt.Println("Usage: waybar-utils power <exit|lock|reboot|shutdown|suspend|hibernate>")
}

func extractClientPIDs(jsonBlob string) []int {
	// hyprctl returns an array of client objects; we only need .pid
	var raw []map[string]any
	if err := json.Unmarshal([]byte(jsonBlob), &raw); err != nil {
		return nil
	}

	out := make([]int, 0, len(raw))
	for _, m := range raw {
		v, ok := m["pid"]
		if !ok {
			continue
		}

		switch t := v.(type) {
		case float64:
			out = append(out, int(t))
		case string:
			if n, err := strconv.Atoi(strings.TrimSpace(t)); err == nil {
				out = append(out, n)
			}
		}
	}

	return out
}

func terminateClients(timeout time.Duration) {
	out, _ := util.MustRunCommand("hyprctl", "clients", "-j")
	pids := extractClientPIDs(out)
	if len(pids) == 0 {
		return
	}

	for _, pid := range pids {
		util.Prefix(fmt.Sprintf("Sending SIGTERM to PID %d", pid))
	}

	_, _ = util.KillPIDs(pids, timeout, false)
	deadline := time.Now().Add(timeout)
	for _, pid := range pids {
		for {
			if err := syscall.Kill(pid, 0); err != nil {
				util.Prefix(fmt.Sprintf("PID %d has terminated.", pid))
				break
			}

			if time.Now().After(deadline) {
				util.Prefix("Timeout reached.")
				return
			}

			util.Prefix(fmt.Sprintf("Waiting for PID %d to terminate...", pid))
			time.Sleep(1 * time.Second)
		}
	}
}
