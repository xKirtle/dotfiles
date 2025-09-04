package main

import (
	"bytes"
	"time"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
	"golang.org/x/sys/unix"
)

func MustStartOrReloadSwaync() {
	if util.IsProcessRunningByName("swaync") {
		util.MustRun("swaync-client", "-rs")
	}

	util.MustRunWith("swaync", nil, util.Detached())
}

func MustWaitForNotificationsBus(timeout time.Duration) {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		out, _ := util.MustRunWith("gdbus",
			[]string{
				"call", "--session",
				"--dest", "org.freedesktop.DBus",
				"--object-path", "/org/freedesktop/DBus",
				"--method", "org.freedesktop.DBus.ListNames",
			},
			util.CaptureOutput(),
			util.CombineOutput(),
		)

		if bytes.Contains(out, []byte("'org.freedesktop.Notifications'")) {
			return
		}

		time.Sleep(100 * time.Millisecond)
	}
}

func MustStartOrReloadWaybar() {
	if util.IsProcessRunningByName("waybar") {
		// https://github.com/Alexays/Waybar/wiki/FAQ#how-can-i-reload-the-configuration-without-restarting-waybar
		if err := util.SignalByName("waybar", unix.SIGUSR2); err == nil {
			return
		}
		// Fallback: if reload signal failed, forcefully kill it and restart
		if _, _, err := util.KillProcessByName("waybar", 2*time.Second, true); err != nil {
			return
		}
	}

	// Not running (or we just killed it): start detached
	util.MustRunWith("waybar", nil, util.Detached())
	return
}
