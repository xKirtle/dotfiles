package main

import (
	"encoding/json"
	"strings"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

func isMediaPlaying() bool {
	if !util.HasBinary("playerctl") {
		return false
	}

	// Simple return false on playerctl transient errors
	out, _, err := util.RunWith("playerctl", []string{"-a", "status"}, util.CaptureOutput(), util.CombineOutput())
	if err != nil {
		return false
	}

	// Check each line of output for "Playing" (case-insensitive)
	for _, ln := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		if strings.EqualFold(strings.TrimSpace(ln), "Playing") {
			return true
		}
	}

	return false
}

const HyprctlFullscreen = 2

func isFullscreen() bool {
	if !util.HasBinary("hyprctl") {
		return false
	}

	out, _, err := util.RunWith("hyprctl", []string{"-j", "activewindow"}, util.CaptureOutput(), util.CombineOutput())
	if err != nil {
		return false
	}

	var payload map[string]any
	if json.Unmarshal(out, &payload) != nil {
		return false
	}

	// Prefer numeric "fullscreen" if present
	if value, ok := payload["fullscreen"]; ok {
		if floatValue, ok := value.(float64); ok {
			return int(floatValue) >= HyprctlFullscreen
		}
	}

	// Fallback: "fullscreenClient" if somehow "fullscreen" is missing
	if value, ok := payload["fullscreenClient"]; ok {
		if floatValue, ok := value.(float64); ok {
			return int(floatValue) >= HyprctlFullscreen
		}
	}

	return false
}
