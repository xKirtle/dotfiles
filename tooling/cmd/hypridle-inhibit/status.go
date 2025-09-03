package main

type WaybarStatus struct {
	Text       string `json:"text"`
	Class      string `json:"class"`
	Percentage int    `json:"percentage"`
	Tooltip    string `json:"tooltip"`
}

func computeStatus() WaybarStatus {
	override := readOverride()
	if override == "" {
		override = "enabled"
	}

	var state, tooltip string
	var pct int

	if override == "disabled" {
		state = "disabled"
		tooltip = "Hypridle manually disabled"
		pct = 0
	} else if isMediaPlaying() || isFullscreen() {
		state = "inhibited"
		tooltip = "Temporarily inhibited (media/fullscreen)"
		pct = 50
	} else {
		state = "active"
		tooltip = "Hypridle active"
		pct = 100
	}

	return WaybarStatus{
		Text:       "",
		Class:      state,
		Percentage: pct,
		Tooltip:    tooltip,
	}
}
