package main

import (
	"time"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

func nmApplet() {
	util.MustHaveBinary("nm-applet")
	if util.IsProcessRunningByName("nm-applet") {
		_, _, err := util.KillProcessByName("nm-applet", 500*time.Millisecond, false)
		util.Check(err, "Failed to kill nm-applet")
	} else {
		util.MustRunWith("nm-applet", []string{"--indicator"}, util.Detached())
	}
}
