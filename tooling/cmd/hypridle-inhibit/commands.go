package main

import (
	"encoding/json"
	"os"
	"strings"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

func cmdToggle()  { toggleOverride(); syncHypridleState() }
func cmdEnable()  { writeOverride("enabled"); syncHypridleState() }
func cmdDisable() { writeOverride("disabled"); syncHypridleState() }

func cmdStatus() {
	st := computeStatus()
	enc := json.NewEncoder(os.Stdout)
	enc.SetEscapeHTML(false)
	util.Check(enc.Encode(st), "write status json")
}

func readOverride() string {
	byteArr, err := os.ReadFile(overrideFile())
	if err != nil {
		return ""
	}

	return strings.ToLower(strings.TrimSpace(string(byteArr)))
}

func writeOverride(v string) {
	p := overrideFile()
	tmp := p + ".tmp"
	util.Check(os.WriteFile(tmp, []byte(v+"\n"), 0644), "write tmp override")
	util.Check(os.Rename(tmp, p), "swap override")
}

func toggleOverride() {
	cur := strings.ToLower(strings.TrimSpace(readOverride()))
	if cur == "enabled" {
		writeOverride("disabled")
	} else {
		writeOverride("enabled")
	}
}
