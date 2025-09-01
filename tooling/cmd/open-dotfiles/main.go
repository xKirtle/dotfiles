package main

import (
	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

func main() {
	target, err := util.JoinHome("dotfiles")
	util.Checkf(err, "failed to get dotfiles path")

	bin := util.MustHaveBinary("code")
	args := []string{"code", "--new-window", target}

	err = util.Exec(bin, args)
	util.CheckExec(err, "failed to exec %q", bin)
}
