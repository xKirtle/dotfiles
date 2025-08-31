package fsx

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
)

func EnsureDir(p string) error { return os.MkdirAll(p, 0o755) }

func IsSymlink(path string) (bool, error) {
	fi, err := os.Lstat(path)
	if err != nil {
		return false, err
	}
	return fi.Mode()&os.ModeSymlink != 0, nil
}

func SymlinkForce(src, dst string) error {
	if err := EnsureDir(filepath.Dir(dst)); err != nil {
		return err
	}
	if fi, err := os.Lstat(dst); err == nil {
		if fi.Mode()&os.ModeSymlink != 0 || fi.Mode().IsRegular() {
			if err := os.Remove(dst); err != nil {
				return err
			}
		} else {
			return os.RemoveAll(dst)
		}
	} else if !errors.Is(err, fs.ErrNotExist) {
		return err
	}
	return os.Symlink(src, dst)
}
