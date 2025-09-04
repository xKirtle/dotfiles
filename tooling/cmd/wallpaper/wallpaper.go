package main

import (
	"errors"
	"fmt"
	"io/fs"
	"math/rand"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

func PickRandomWallpaper(dir string, cachePath string) (string, error) {
	if dir == "" || !util.IsDirectory(dir) {
		return "", errors.New("wallpaper dir not found: " + dir)
	}

	var imgs []string
	_ = filepath.WalkDir(dir, func(p string, d fs.DirEntry, _ error) error {
		if d != nil && !d.IsDir() && isImage(p) {
			imgs = append(imgs, p)
		}
		return nil
	})

	if len(imgs) == 0 {
		return "", errors.New("no images in " + dir)
	}

	// Try to exclude the last-picked file from the candidates
	if cachePath != "" && util.PathExists(cachePath) {
		if b, err := os.ReadFile(cachePath); err == nil {
			last := strings.TrimSpace(string(b))
			last = filepath.Clean(last)

			filtered := imgs[:0]
			for _, p := range imgs {
				if filepath.Clean(p) != last {
					filtered = append(filtered, p)
				}
			}

			if len(filtered) > 0 {
				imgs = filtered
			}
		}
	}

	rand.New(rand.NewSource(time.Now().UnixNano()))
	return imgs[rand.Intn(len(imgs))], nil
}

func isImage(p string) bool {
	switch strings.ToLower(filepath.Ext(p)) {
	case ".jpg", ".jpeg", ".png", ".webp":
		return true
	default:
		return false
	}
}

func MustEnsureHyprpaper() {
	if util.IsProcessRunningByName("hyprpaper") {
		return
	}
	util.MustRunWith("hyprpaper", nil, util.Detached())
	time.Sleep(200 * time.Millisecond) // same idea as the shell sleep
}

func hyprctlArgs(extra ...string) []string {
	if sig := os.Getenv("HYPRLAND_INSTANCE_SIGNATURE"); sig != "" {
		return append([]string{"-i", sig}, extra...)
	}
	return extra
}

func MustSetWallpaper(path, cachePath string) {
	const retryCount = 4
	const retryDelay = 60 * time.Millisecond

	try := func(args ...string) error {
		_, _, err := util.RunWith("hyprctl", args)
		return err
	}

	// try once fast, then a few short retries only on error
	if err := try(hyprctlArgs("hyprpaper", "preload", path)...); err != nil {
		for i := 0; i < retryCount; i++ { // 4 * 60ms = 240ms worst-case
			time.Sleep(retryDelay)
			if try(hyprctlArgs("hyprpaper", "preload", path)...) == nil {
				break
			}
		}
	}
	if err := try(hyprctlArgs("hyprpaper", "wallpaper", ","+path)...); err != nil {
		for i := 0; i < retryCount; i++ {
			time.Sleep(retryDelay)
			if try(hyprctlArgs("hyprpaper", "wallpaper", ","+path)...) == nil {
				break
			}
		}
	}

	if cachePath != "" {
		if err := writeStringAtomic(cachePath, path+"\n"); err != nil {
			fmt.Printf("Failed to cache %s: %v\n", path, err)
		}
	}
}

// atomic-ish write: tmp file + rename
func writeStringAtomic(dest, str string) error {
	dir := filepath.Dir(dest)
	if err := util.EnsureDirectory(dir); err != nil {
		return err
	}

	tmp, err := os.CreateTemp(dir, ".tmp-*")
	if err != nil {
		return err
	}

	tmpName := tmp.Name()
	_, werr := tmp.WriteString(str)
	cerr := tmp.Close()
	if werr != nil {
		_ = os.Remove(tmpName)
		return werr
	}

	if cerr != nil {
		_ = os.Remove(tmpName)
		return cerr
	}

	return os.Rename(tmpName, dest)
}
