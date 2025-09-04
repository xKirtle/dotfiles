package main

import (
	"errors"
	"path/filepath"

	"github.com/xKirtle/dotfiles/tooling/internal/util"
)

func UpdateSDDM(img, bgTarget, confTarget string) error {
	if bgTarget == "" && confTarget == "" {
		return nil
	}
	if bgTarget != "" {
		_, _, err := util.RunWith("sudo", []string{"cp", "-f", "--", img, bgTarget})
		if err != nil {
			return err
		}
	}
	if confTarget != "" {
		src := filepath.Join(util.HomeDir(), ".config/matugen/sddm.conf")
		if !util.PathExists(src) {
			return errors.New("Matugen SDDM config not found: " + src)
		}
		if _, _, err := util.RunWith("sudo", []string{"cp", "-f", "--", src, confTarget}); err != nil {
			return err
		}
		_, _, _ = util.RunWith("rm", []string{"-f", "--", src})
	}
	return nil
}
