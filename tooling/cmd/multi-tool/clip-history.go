package main

import (
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

func wofiPickItem(prompt string, lines int, styleFlag []string) string {
	clipHistList, _ := util.MustRunCommand("cliphist", "list")
	wofiArgs := getWofiArgs(prompt, lines, styleFlag)
	out, _ := util.MustRunCommandWithInput(clipHistList, "wofi", wofiArgs...)

	return strings.TrimSpace(out)
}

func wofiCopyItem(styleFlag []string) {
	util.MustHaveBinary("wl-copy")

	sel := wofiPickItem("Clipboard", 20, styleFlag)
	if sel == "" {
		os.Exit(util.ExitSuccess)
	}

	// Decode in bytes to preserve images/files
	decoded, _ := util.MustRunCommandBytesWithInput([]byte(sel), "cliphist", "decode")
	util.MustRunInteractiveBytesWithInput(decoded, true, "wl-copy")
}

func wofiDeleteItem(styleFlag []string) {
	sel := wofiPickItem("Delete clipboard entry", 20, styleFlag)
	if sel == "" {
		os.Exit(util.ExitSuccess)
	}

	util.MustRunCommandWithInput(sel, "cliphist", "delete")
}

func wofiWipeAllEntries(styleFlag []string) {
	wofiArgs := getWofiArgs("Wipe Clipboard History", 2, styleFlag)
	out, _ := util.MustRunCommandWithInput("Wipe All\nCancel\n", "wofi", wofiArgs...)
	out = strings.TrimSpace(out)

	if out == "Wipe All" {
		util.MustRunCommand("cliphist", "wipe")
	}
}

func getWofiArgs(prompt string, lines int, styleFlag []string) []string {
	return append([]string{"--dmenu", "--prompt", prompt, "-i", "-l", fmt.Sprint(lines), "--cache-file", os.DevNull}, styleFlag...)
}
