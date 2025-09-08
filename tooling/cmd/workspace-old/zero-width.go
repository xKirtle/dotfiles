package main

import (
	"regexp"
	"strconv"
	"strings"
)

func zeroWidthToken(monitorID int) string {
	switch monitorID {
	case 0:
		return "\u2060\u200D"
	case 1:
		return "\u200D\u2060"
	default:
		return "\u200E\u200F"
	}
}

func ZeroWidthName(monitorID, slot int) string {
	return strconv.Itoa(slot) + zeroWidthToken(monitorID)
}

var invisibleChars = regexp.MustCompile("[\u200B\u200C\u200D\u200E\u200F\u2060]")

func TrimZeroWidth(name string) string {
	return invisibleChars.ReplaceAllString(name, "")
}

func IsNumericWorkspace(name string) bool {
	if name == "" || invisibleChars.MatchString(name) {
		return false
	}

	for _, char := range name {
		if char < '0' || char > '9' {
			return false
		}
	}

	return true
}

func ParseLocalSlot(name string, monitorID int) int {
	if IsNumericWorkspace(name) {
		slot, _ := strconv.Atoi(TrimZeroWidth(name))
		return slot
	}

	token := zeroWidthToken(monitorID)
	if !strings.HasSuffix(name, token) {
		return 0
	}

	slot := strings.TrimSuffix(name, token)
	if invisibleChars.MatchString(slot) || slot == "" {
		return 0
	}

	for _, char := range slot {
		if char < '0' || char > '9' {
			return 0
		}
	}

	slotInt, err := strconv.Atoi(slot)
	if err != nil {
		return 0
	}

	return slotInt
}
