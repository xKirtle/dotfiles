package util

import (
	"fmt"
	"os"

	"golang.org/x/term"
)

// ClearScreen attempts to clear the terminal screen in a way that respects
// terminal capabilities and only does so if stdout is a terminal (TTY).
// It first tries to use 'tput clear', then falls back to 'clear', and finally
// uses ANSI escape codes if neither command is available.
func ClearScreen() {
	// Only attempt to clear the screen if stdout is a terminal
	// This prevents issues when output is being piped or redirected
	// to a file, where clearing the screen would be inappropriate
	if !isTTY() {
		return
	}

	// Try using 'tput clear' first, as it respects terminal capabilities
	if HasBinary("tput") {

		if _, _, err := RunWith("tput", []string{"clear"}, Interactive()); err == nil {
			return
		}
	}

	// Fallback to 'clear' command if 'tput' is not available
	if HasBinary("clear") {
		if _, _, err := RunWith("clear", nil, Interactive()); err == nil {
			return
		}
	}

	// If both commands are unavailable, use ANSI escape codes
	clearScreenANSI()
}

func isTTY() bool {
	return term.IsTerminal(int(os.Stdout.Fd()))
}

func clearScreenANSI() {
	// \033 is the escape character, equivalent to 0x1B in octal or ESC
	// [2J clears the entire screen
	// [H moves the cursor to the home position (top-left corner)
	// Combining these sequences effectively clears the terminal screen and resets the cursor position
	fmt.Print("\033[2J\033[H")
}

func PrintHeaderBanner(text string) {
	if HasBinary("figlet") {
		MustRunWith("figlet", []string{"-f", "smslant", text}, Interactive())
	} else {
		fmt.Printf("==== %s ====\n", text)
	}
}

func Prefix(msg string) {
	const (
		blue  = "\u001b[34m"
		reset = "\u001b[0m"
	)
	fmt.Printf("%s%s%s %s\n", blue, "::", reset, msg)
}
