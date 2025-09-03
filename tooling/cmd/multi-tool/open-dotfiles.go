package main

import "github.com/xKirtle/dotfiles/tooling/internal/util"

func openDotfiles() {
	target := util.JoinHome("dotfiles")
	util.MustHaveBinary("code")
	util.MustRunWith("code", []string{"--new-window", target}, util.Detached())
}
