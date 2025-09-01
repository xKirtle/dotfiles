package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

type waybarOut struct {
	Text    string `json:"text"`
	Alt     string `json:"alt"`
	Tooltip string `json:"tooltip"`
	Class   string `json:"class"`
}

func RunFindUpdates(opts CheckOptions) {
	// Arch only (by design)
	if !util.HasBinary("pacman") {
		return
	}

	waitForLocks()

	n, err := countUpdatesArch()
	if err != nil {
		// If tooling missing or some transient error, do not spam Waybar; print nothing.
		return
	}

	if !opts.EmitJSON {
		fmt.Println(n)
		return
	}

	class := "green"
	if n > opts.ThresholdYellow {
		class = "yellow"
	}
	if n > opts.ThresholdRed {
		class = "red"
	}

	if n != 0 {
		if n > opts.ThresholdGreen {
			_ = json.NewEncoder(os.Stdout).Encode(waybarOut{
				Text:    strconv.Itoa(n),
				Alt:     strconv.Itoa(n),
				Tooltip: "Click to update your system",
				Class:   class,
			})
		} else {
			_ = json.NewEncoder(os.Stdout).Encode(waybarOut{
				Text:    "0",
				Alt:     "0",
				Tooltip: "No updates available",
				Class:   "green",
			})
		}
	}
}

func waitForLocks() {
	pacmanLock := "/var/lib/pacman/db.lck"

	tmpdir := os.TempDir()
	checkupLock := filepath.Join(tmpdir, fmt.Sprintf("checkup-db-%d", os.Getuid()), "db.lck")

	for {
		if !fileExists(pacmanLock) && !fileExists(checkupLock) {
			return
		}
		time.Sleep(1 * time.Second)
	}
}

func fileExists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}

func countUpdatesArch() (int, error) {
	tool := "checkupdates-with-aur"
	if !util.HasBinary(tool) {
		return 0, fmt.Errorf("%s not found", tool)
	}

	// Run and capture stdout
	cmd := exec.Command(tool)
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return 0, err
	}
	if err := cmd.Start(); err != nil {
		return 0, err
	}

	// Count lines efficiently via scanner
	sc := bufio.NewScanner(stdout)
	count := 0
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line != "" {
			count++
		}
	}
	_ = cmd.Wait() // we don't care about its exit code; empty output is 0 updates

	return count, nil
}
