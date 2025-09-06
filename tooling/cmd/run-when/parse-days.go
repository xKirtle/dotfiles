package main

import (
	"fmt"
	"strings"
	"time"
)

var weekDayMap = map[string]time.Weekday{
	"sun": time.Sunday, "sunday": time.Sunday,
	"mon": time.Monday, "monday": time.Monday,
	"tue": time.Tuesday, "tuesday": time.Tuesday,
	"wed": time.Wednesday, "wednesday": time.Wednesday,
	"thu": time.Thursday, "thursday": time.Thursday,
	"fri": time.Friday, "friday": time.Friday,
	"sat": time.Saturday, "saturday": time.Saturday,
}

func stringToWeekday(s string) (time.Weekday, bool) {
	wd, ok := weekDayMap[strings.ToLower(strings.TrimSpace(s))]
	return wd, ok
}

// parseDays parses lists, ranges (wrap ok), and keywords: weekdays/weekend(s).
func parseDays(days string) (DayBitset, error) {
	days = strings.ToLower(strings.TrimSpace(days))
	// Basic validation, we should never get here due to earlier checks anyway
	if days == "" {
		return 0, fmt.Errorf("empty days string")
	}

	daysBitset := DayBitset(0)
	switch days {
	case "weekdays":
		daysBitset = daysBitset.Pack(time.Monday, time.Tuesday, time.Wednesday, time.Thursday, time.Friday)
		return daysBitset, nil
	case "weekend", "weekends":
		daysBitset = daysBitset.Pack(time.Saturday, time.Sunday)
		return daysBitset, nil
	}

	parts := strings.Split(days, ",")
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}

		// Ranges
		if strings.Contains(part, "..") {
			start, end, found := strings.Cut(part, "..")
			if !found {
				return 0, fmt.Errorf("invalid range: %s", part)
			}

			startDay, startFound := stringToWeekday(start)
			endDay, endFound := stringToWeekday(end)

			if !startFound || !endFound {
				return 0, fmt.Errorf("invalid weekday in range: %s", part)
			}

			daysBitset = daysBitset.PackRange(startDay, endDay)
			continue
		}

		// Single days
		day, found := stringToWeekday(part)
		if !found {
			return 0, fmt.Errorf("invalid weekday: %s", part)
		}

		daysBitset = daysBitset.Pack(day)
	}

	if daysBitset == 0 {
		return 0, fmt.Errorf("no valid days parsed from input")
	}

	return daysBitset, nil
}
