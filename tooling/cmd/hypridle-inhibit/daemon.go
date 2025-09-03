package main

import (
	"path/filepath"
	"time"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

// cmdDaemon: single-instance, long-lived loop. Checks sensors and starts/stops hypridle periodically
func cmdDaemon() {
	acquireDaemonLock()
	defer releaseDaemonLock()

	util.Prefix("hypridle-inhibit: daemon start")
	syncHypridleState()

	t := time.NewTicker(checkEvery)
	defer t.Stop()
	for range t.C {
		syncHypridleState()
	}
}

// syncHypridleState enforces the desired policy by starting or stopping hypridle.
// It is idempotent and safe to call periodically
func syncHypridleState() {
	shouldProcBeRunning := shouldHypridleBeRunning()
	isProcRunning := util.IsProcessRunningByName(filepath.Base("hypridle"))

	switch {
	case shouldProcBeRunning && !isProcRunning:
		startHypridle()
	case !shouldProcBeRunning && isProcRunning:
		stopHypridle()
	}
}

// shouldHypridleBeRunning computes whether hypridle should be running
func shouldHypridleBeRunning() bool {
	overrideFile := readOverride()
	isMediaPlaying := isMediaPlaying()
	isFullscreen := isFullscreen()

	return overrideFile == "" && !(isMediaPlaying || isFullscreen)
}
