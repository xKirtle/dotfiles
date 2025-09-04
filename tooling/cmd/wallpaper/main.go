package main

import (
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

var (
	flagRandom = flag.Bool("random", false, "Pick a random image from WALLPAPER_DIR")
	flagFile   = flag.String("file", "", "Use a specific file as wallpaper\n(mutually exclusive with --random)")
	flagSDDM   = flag.Bool("sddm", false, "Force updating SDDM background + theme config from Matugen")
	flagNoWait = flag.Bool("no-wait-bus", false, "Skip waiting for org.freedesktop.Notifications")
)

func main() {
	flag.Parse()

	// If no flags were set, or leftover args exist, show usage & exit
	if flag.NFlag() == 0 || flag.NArg() > 0 {
		usage()
		os.Exit(util.ExitMissingArgs)
	}

	if *flagFile != "" && *flagRandom {
		_, _ = fmt.Fprintln(os.Stderr, "Error: --file and --random are mutually exclusive")
		usage()
		os.Exit(util.ExitMissingArgs)
	}

	cfg := LoadConfig()

	// Fail early if a required binary is missing
	reqBins := []string{"hyprctl", "hyprpaper", "matugen", "wallust", "waybar", "swaync", "swaync-client"}
	if !*flagNoWait {
		reqBins = append(reqBins, "gdbus")
	}

	for _, bin := range reqBins {
		if !util.HasBinary(bin) {
			util.Fatalf(util.ExitNotFound, "required binary missing: %s", bin)
		}
	}

	// Choose wallpaper
	var wallpaper string
	switch {
	case *flagFile != "":
		wallpaper = *flagFile
	case *flagRandom:
		var err error
		wallpaper, err = PickRandomWallpaper(cfg.WallpaperDir, cfg.WPFCachedPath)
		if err != nil {
			util.Fatalf(util.ExitFailure, "random pick failed: %v", err)
		}
	default:
		wallpaper = cfg.DefaultWallpaper
	}

	// Can be redundant if we picked a random wallpaper, but that's okay
	if !util.PathExists(wallpaper) {
		util.Fatalf(util.ExitFailure, "Chosen wallpaper does not exist: %s", wallpaper)
	}

	fmt.Println("Picked wallpaper:", wallpaper)

	// Sequence: hyprpaper -> set wallpaper -> themers -> swaync -> (wait bus) -> waybar -> (SDDM)
	MustEnsureHyprpaper()
	MustSetWallpaper(wallpaper, cfg.WPFCachedPath)
	MustRunThemers(wallpaper)
	MustStartOrReloadSwaync()

	if !*flagNoWait {
		MustWaitForNotificationsBus(5 * time.Second)
	}

	MustStartOrReloadWaybar()

	if *flagSDDM {
		if err := UpdateSDDM(wallpaper, cfg.SDDMBackgroundTarget, cfg.SDDMConfTarget); err != nil {
			util.Fatalf(util.ExitFailure, "sddm: %v", err)
		}
	}

	os.Exit(util.ExitSuccess)
}

func usage() {
	_, _ = fmt.Fprintf(flag.CommandLine.Output(), `Usage: wallpaper [--random | --file PATH] [--sddm] [--no-wait-bus]

Options:
  --random         Pick a random wallpaper from WALLPAPER_DIR
  --file PATH      Use a specific file as wallpaper
                   (mutually exclusive with --random)
  --sddm           Update SDDM background and theme config
  --no-wait-bus    Skip waiting for notifications bus
  -h, --help       Show this help message
`)
}
