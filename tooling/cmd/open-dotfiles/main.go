package main

import (
	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

func main() {
	target := util.JoinHome("dotfiles")
	code := util.MustHaveBinary("code")
	err := util.Exec(code, "--new-window", target)
	util.CheckExec(err, "failed to exec %q", code)
}
