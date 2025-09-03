package main

import (
	"time"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

func startHypridle() {
	util.MustHaveBinary("hypridle")
	_, _, err := util.RunWith("hypridle", nil, util.Detached())
	util.Check(err, "start hypridle")
}

func stopHypridle() {
	_, _, err := util.KillProcessByName("hypridle", 600*time.Millisecond, true)
	util.Check(err, "stop hypridle")
}
