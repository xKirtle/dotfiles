package main

import "time"

// Simple bitset to hold all days of the week in a single byte and common operations

type DayBitset uint8

func (dayBitset DayBitset) Pack(days ...time.Weekday) DayBitset {
	for _, day := range days {
		dayBitset |= DayBitset(1) << uint(day)
	}

	return dayBitset
}

// PackRange adds all days from start..end (inclusive), wrapping across week if needed (e.g. Fri..Mon)
func (dayBitset DayBitset) PackRange(start, end time.Weekday) DayBitset {
	for day := start; ; day = (day + 1) % 7 {
		dayBitset |= DayBitset(1) << uint(day)
		if day == end {
			break
		}
	}

	return dayBitset
}

func (dayBitset DayBitset) Has(d time.Weekday) bool {
	return dayBitset&(DayBitset(1)<<uint(d)) != 0
}

func (dayBitset DayBitset) Unpack() []time.Weekday {
	out := make([]time.Weekday, 0, 7)
	for d := time.Sunday; d <= time.Saturday; d++ {
		if dayBitset.Has(d) {
			out = append(out, d)
		}
	}

	return out
}
