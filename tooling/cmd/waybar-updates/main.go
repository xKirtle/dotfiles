package main

import (
	"fmt"
	"time"

	"github.com/xKirtle/dotfiles/tooling/internal/waybar"
)

func main() {
	t := time.NewTicker(30 * time.Second)
	defer t.Stop()

	for range t.C {
		_ = waybar.Print(waybar.Out{
			Text:  fmt.Sprintf("%d ⬆", 0),
			Class: "ok",
		})
	}
}
