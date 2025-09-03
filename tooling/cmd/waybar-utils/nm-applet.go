package main

import (
	"time"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

func nmApplet(args []string) {
	util.MustHaveBinary("nm-applet")

	if len(args) == 1 && args[0] == "--toggle" {
		if util.IsProcessRunningByName("nm-applet") {
			_, _, err := util.KillProcessByName("nm-applet", 500*time.Millisecond, false)
			util.Checkf(err, "Failed to kill nm-applet")
		} else {
			err := util.RunCommandDetached("nm-applet", "--indicator")
			util.Checkf(err, "Failed to start nm-applet")
		}
	}
}
