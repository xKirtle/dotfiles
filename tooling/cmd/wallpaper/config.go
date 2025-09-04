package main

import (
	"os"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

type Config struct {
	DefaultWallpaper     string
	HyprpaperConf        string
	WPFCachedPath        string
	WallpaperDir         string
	SDDMBackgroundTarget string
	SDDMConfTarget       string
}

func envOr(def, key string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func LoadConfig() Config {
	return Config{
		DefaultWallpaper:     envOr("/usr/share/wallpapers/cachyos-wallpapers/Skyscraper.png", "DEFAULT_WP"),
		HyprpaperConf:        envOr(util.JoinHome(".config/hypr/hyprpaper.conf"), "HCONF"),
		WPFCachedPath:        envOr(util.JoinHome(".cache/hyprpaper.fingerprint"), "WPF_CACHE"),
		WallpaperDir:         envOr(util.JoinHome("Pictures/Wallpapers"), "WALLPAPER_DIR"),
		SDDMBackgroundTarget: envOr("/usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds/dynamic.jpg", "SDDM_BG_TARGET"),
		SDDMConfTarget:       envOr("/usr/share/sddm/themes/sddm-astronaut-theme/Themes/custom.conf", "SDDM_CONF_TARGET"),
	}
}
