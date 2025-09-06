package main

import (
	"fmt"
	"strings"
	"time"
)

// Parse "HH:MM" (24h) → duration since midnight (local).
func parseHHMMDur(s string) (time.Duration, error) {
	s = strings.TrimSpace(s)
	if len(s) != 5 || s[2] != ':' {
		return 0, fmt.Errorf("time must be HH:MM 24h (e.g., 09:00, 22:30), got %q", s)
	}

	// Huge wall of code, but we're simply validating if each char is a digit and then parsing
	h1, h2, m1, m2 := s[0], s[1], s[3], s[4]
	if h1 < '0' || h1 > '9' || h2 < '0' || h2 > '9' || m1 < '0' || m1 > '9' || m2 < '0' || m2 > '9' {
		return 0, fmt.Errorf("time must be digits in HH:MM, got %q", s)
	}

	h := int(h1-'0')*10 + int(h2-'0')
	m := int(m1-'0')*10 + int(m2-'0')
	if h > 23 || m > 59 {
		return 0, fmt.Errorf("invalid time %02d:%02d", h, m)
	}

	return time.Duration(h)*time.Hour + time.Duration(m)*time.Minute, nil
}
