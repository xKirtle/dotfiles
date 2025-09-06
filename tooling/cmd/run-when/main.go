package main

import (
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

func main() {
	const ExitMissingArgs = 2 // No point importing entire util package just for this

	var (
		days  string
		start string
		end   string
	)

	flag.StringVar(&days, "days", "", "Day selector (e.g. Mon..Fri, Mon,Wed,Fri, weekdays, weekends)")
	flag.StringVar(&start, "start", "00:00", "start time (HH:MM 24h)")
	flag.StringVar(&end, "end", "23:59", "end time (HH:MM 24h)")
	flag.Parse()

	cmd := flag.Args() // Remaining args after flags '-- {cmd...}'
	if len(cmd) == 0 {
		FatalfWithUsage(ExitMissingArgs, "Missing command to run after flags, e.g. -- notify-send 'Hello'\n")
	}

	if days == "" {
		FatalfWithUsage(ExitMissingArgs, "Missing required --days argument\n")
	}

	daySet, err := parseDays(days)
	Check(err, ExitMissingArgs, "Error parsing --days %v\n", err)

	startDur, err := parseHHMMDur(start)
	Check(err, ExitMissingArgs, "Error parsing --start %v\n", err)

	endDur, err := parseHHMMDur(end)
	Check(err, ExitMissingArgs, "Error parsing --end %v\n", err)

	if allowedNow(daySet, startDur, endDur, time.Now()) {
		util.MustRunWith(cmd[0], cmd[1:], util.Detached())
	}
}

func Check(err error, exitCode int, format string, args ...any) {
	if err == nil {
		return
	}

	FatalfWithUsage(exitCode, format, args...)
}

func FatalfWithUsage(exitCode int, format string, args ...any) {
	fmt.Printf(format, args...)
	flag.Usage()
	os.Exit(exitCode)
}
