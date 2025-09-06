package main

import "time"

func prevWeekday(w time.Weekday) time.Weekday {
	return (w + 6) % 7 // wrap Sun->Sat
}

// Returns true if "now" (local) is within [start,end) subject to day rules.
// Cross-midnight windows (start > end) spill into the *next* calendar day
// but remain attributed to the *start* day.
func allowedNow(daySet DayBitset, start, end time.Duration, now time.Time) bool {
	now = now.In(time.Local)
	nowDuration := time.Duration(now.Hour())*time.Hour + time.Duration(now.Minute())*time.Minute
	todayWeekday := now.Weekday()

	switch {
	case start == end:
		// 00:00..00:00 means “all day” on allowed days.
		return daySet.Has(todayWeekday)

	case start < end:
		// Same-day window: require todayWeekday in set and time inside [start,end).
		return daySet.Has(todayWeekday) && (nowDuration >= start && nowDuration < end)

	default:
		// Cross-midnight: split into two pieces:
		// - Late piece on the start day: [start, 24:00) -> requires TODAY in set
		// - Early piece on the next day: [00:00, end) -> requires YESTERDAY in set
		if nowDuration >= start {
			return daySet.Has(todayWeekday)
		}
		// Early-morning spillover
		yesterday := prevWeekday(todayWeekday)
		return daySet.Has(yesterday) && (nowDuration < end)
	}
}
