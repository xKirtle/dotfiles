package main

import (
	"bufio"
	"bytes"
	"fmt"
	"regexp"
	"strings"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

type Sink struct {
	ID      string
	Name    string
	Enabled bool // true if line has the '*' marker in wpctl status
}

func cycleAudioSink(args []string) {
	if len(args) != 1 || (len(args) == 1 && args[0] != "next" && args[0] != "prev") {
		printCycleAudioSinkUsage()
		return
	}

	cycleDirection := args[0]
	util.MustHaveBinary("wpctl")

	sinks, err := listSinksFromStatus()
	util.Check(err, "wpctl status parsing failed") // shell-like exit codes on error :contentReference[oaicite:2]{index=2}
	if len(sinks) == 0 {
		tryNotify("⚠️ No audio sinks found.", "")
		util.Fatalf(util.ExitFailure, "no audio sinks found") // :contentReference[oaicite:3]{index=3}
	}

	cur := indexEnabled(sinks)
	var target int
	switch cycleDirection {
	case "prev":
		target = (cur - 1 + len(sinks)) % len(sinks)
	default: // next
		target = (cur + 1) % len(sinks)
	}

	if target == cur {
		tryNotify("🔊 Output unchanged", friendly(sinks[cur]))
		return
	}

	// Switch default sink
	util.MustRun("wpctl", "set-default", sinks[target].ID)
	tryNotify("🔊 Output switched", friendly(sinks[target]))
}

func printCycleAudioSinkUsage() {
	fmt.Println("Usage: cycle-audio-sink [next|prev]")
}

func indexEnabled(sinks []Sink) int {
	for i, sink := range sinks {
		if sink.Enabled {
			return i
		}
	}

	return 0 // fallback if none marked
}

func friendly(s Sink) string {
	if s.Name != "" {
		return s.Name
	}

	return fmt.Sprintf("ID %s", s.ID)
}

// Example line (with star):
// "│  *   43. Family 17h/19h/1ah HD Audio Controller Digital Stereo (IEC958) [vol: 0.43]"
// Example line (no star):
// "│      78. Scarlett Solo 4th Gen Headphones / Line 1-2 [vol: 0.54]"
var sinkRegex = regexp.MustCompile(`^\s*[│]*\s*(\*?)\s*(\d+)\.\s+(.*)$`)

func listSinksFromStatus() ([]Sink, error) {
	out, _, err := util.RunWith("wpctl", []string{"status"}, util.CaptureOutput()) // capture output :contentReference[oaicite:5]{index=5}
	if err != nil {
		return nil, err
	}

	scanner := bufio.NewScanner(bytes.NewReader(out))
	isSinksSection := false
	seen := make(map[string]bool)
	var sinks []Sink

	for scanner.Scan() {
		line := scanner.Text()

		if strings.Contains(line, "Sinks:") {
			isSinksSection = true
			continue
		}
		if strings.Contains(line, "Sources:") {
			isSinksSection = false
		}

		if !isSinksSection {
			continue
		}

		splicedSink := sinkRegex.FindStringSubmatch(line)
		if splicedSink == nil {
			continue
		}

		enabled := splicedSink[1] == "*"
		id := splicedSink[2]
		name := trimNameTail(splicedSink[3]) // drop trailing " [vol: ...]"

		if !seen[id] {
			seen[id] = true
			sinks = append(sinks, Sink{ID: id, Name: name, Enabled: enabled})
		}
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}

	// If none marked Enabled, keep order and mark first
	if len(sinks) > 0 {
		found := false
		for _, sink := range sinks {
			if sink.Enabled {
				found = true
				break
			}
		}

		if !found {
			sinks[0].Enabled = true
		}
	}

	return sinks, nil
}

func trimNameTail(s string) string {
	// wpctl appends volume and possibly other attrs in brackets.
	// Cut at the last " [" if present, else keep full string.
	if i := strings.LastIndex(s, " ["); i >= 0 {
		return strings.TrimSpace(s[:i])
	}

	return strings.TrimSpace(s)
}

func tryNotify(summary, body string) {
	if !util.HasBinary("notify-send") {
		return
	}

	args := []string{summary}
	if body != "" {
		args = append(args, body)
	}

	_, _, _ = util.RunWith("notify-send", args) // fire and forget
}
