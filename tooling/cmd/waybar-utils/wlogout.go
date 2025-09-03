package main

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"os/exec"
	"strconv"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

type monitor struct {
	Width   int     `json:"width"`
	Height  int     `json:"height"`
	Scale   float64 `json:"scale"`
	Focused bool    `json:"focused"`
}

func wlogout() {
	out, err := exec.Command("hyprctl", "-j", "monitors").Output()
	if err != nil {
		_, err := fmt.Fprintf(os.Stderr, "failed to run hyprctl: %v\n", err)
		util.Checkf(err, "failed to write to stderr")
		os.Exit(util.ExitFailure)
	}

	var mons []monitor
	if err := json.Unmarshal(out, &mons); err != nil {
		_, err := fmt.Fprintf(os.Stderr, "invalid hyprctl JSON: %v\n", err)
		util.Checkf(err, "failed to write to stderr")
		os.Exit(util.ExitFailure)
	}

	var m *monitor
	for i := range mons {
		if mons[i].Focused {
			m = &mons[i]
			break
		}
	}

	if m == nil {
		_, err := fmt.Fprintln(os.Stderr, "no focused monitor found")
		util.Checkf(err, "failed to write to stderr")
		os.Exit(util.ExitFailure)
	}

	if m.Scale == 0 {
		_, err := fmt.Fprintln(os.Stderr, "monitor scale is zero (unexpected)")
		util.Checkf(err, "failed to write to stderr")
		os.Exit(util.ExitFailure)
	}

	wMargin := int(math.Round(float64(m.Height) * 27.0 / m.Scale))

	cmd := exec.Command("wlogout",
		"-b", "5",
		"-T", strconv.Itoa(wMargin),
		"-B", strconv.Itoa(wMargin),
	)

	if err := cmd.Run(); err != nil {
		_, err := fmt.Fprintf(os.Stderr, "failed to run wlogout: %v\n", err)
		util.Checkf(err, "failed to write to stderr")
		os.Exit(util.ExitFailure)
	}
}
