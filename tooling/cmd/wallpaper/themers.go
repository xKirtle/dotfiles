package main

import (
	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

func MustRunThemers(img string) {
	mustRunMatugen(img)
	mustRunWallust(img)
}

func mustRunMatugen(img string) {
	cfg := util.JoinHome(".config/matugen/config.toml")
	util.MustRunWith("matugen", []string{"image", img, "--config", cfg})
}

func mustRunWallust(img string) {
	util.MustRunWith("wallust", []string{"run", img, "--config-dir", util.JoinHome("~/.config/wallust")})
}
