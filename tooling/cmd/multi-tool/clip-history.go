package main

import (
	"bytes"
	"fmt"
	"os"
	"strings"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

func clipboardHistory(args []string) {
	util.MustHaveBinary("cliphist")
	util.MustHaveBinary("wofi")

	styleFile := util.JoinHome(".config/wofi/style.css")
	var styleFlag []string
	if util.PathExists(styleFile) {
		styleFlag = []string{"--style", styleFile}
	}

	if (len(args) == 1 && (args[0] != "d" && args[0] != "w")) || len(args) > 1 {
		printClipboardHistoryUsage()
		os.Exit(util.ExitMissingArgs)
	}

	mode := ""
	if len(args) == 1 {
		mode = args[0]
	}

	switch mode {
	case "d":
		wofiDeleteItem(styleFlag)
	case "w":
		wofiWipeAllEntries(styleFlag)
	default:
		wofiCopyItem(styleFlag)
	}

	os.Exit(util.ExitSuccess)
}

func printClipboardHistoryUsage() {
	fmt.Println(`Usage: clip-history [d|w]
  
  d: delete selected entry
  w: wipe all entries
  (no arg): copy selected entry to clipboard`)
}

func wofiPickItem(prompt string, lines int, styleFlag []string) []byte {
	list, _ := util.MustRunWith("cliphist", []string{"list"}, util.CaptureOutput())
	wofiArgs := getWofiArgs(prompt, lines, styleFlag)
	sel, _ := util.MustRunWith("wofi", wofiArgs, util.WithInputBytes(list), util.CaptureOutput())

	return bytes.TrimSpace(sel)
}

func wofiCopyItem(styleFlag []string) {
	util.MustHaveBinary("wl-copy")

	sel := wofiPickItem("Clipboard", 20, styleFlag)
	if len(sel) == 0 {
		return // no selection or cancelled, exit silently
	}

	decoded, _ := util.MustRunWith("cliphist", []string{"decode"}, util.WithInputBytes(sel), util.CaptureOutput())
	util.MustRunWith("wl-copy", nil, util.WithInputBytes(decoded), util.Interactive(), util.DropStderr())
}

func wofiDeleteItem(styleFlag []string) {
	sel := wofiPickItem("Delete clipboard entry", 20, styleFlag)
	if len(sel) == 0 {
		return // no selection or cancelled, exit silently
	}

	util.MustRunWith("cliphist", []string{"delete"}, util.WithInputBytes(sel))
}

func wofiWipeAllEntries(styleFlag []string) {
	wofiArgs := getWofiArgs("Wipe Clipboard History", 2, styleFlag)
	out, _ := util.MustRunWith("wofi", wofiArgs, util.WithInputString("Wipe All\nCancel\n"), util.CaptureOutput())
	if strings.TrimSpace(string(out)) == "Wipe All" {
		util.MustRun("cliphist", "wipe")
	}
}

func getWofiArgs(prompt string, lines int, styleFlag []string) []string {
	return append([]string{"--dmenu", "--prompt", prompt, "-i", "-l", fmt.Sprint(lines), "--cache-file", os.DevNull}, styleFlag...)
}
