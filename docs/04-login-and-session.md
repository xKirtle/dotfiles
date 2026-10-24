# Login screen and session

## Login screen: greetd + ReGreet (replaced SDDM)

**Why:** SDDM's default setup drew its greeter with Xorg. On this NVIDIA + AMD-iGPU machine
the screen went black a second after appearing, and the default theme looked dated. greetd runs
the ReGreet greeter **inside a minimal Hyprland**: the same Wayland/NVIDIA path the desktop uses.

| File | Purpose |
|---|---|
| `/etc/greetd/config.toml` | `command = "dbus-run-session start-hyprland -- -c /etc/greetd/hyprland.lua"`, `user = "greeter"`, `vt = 1` |
| `/etc/greetd/hyprland.lua` | greeter's Hyprland: monitors **by description** (same layout/rotation as desktop), NVIDIA env, US/PT layouts, mouse settings, Catppuccin background, window rule putting ReGreet (`apps.regreet`) on the main monitor, exits after login |
| `/etc/greetd/regreet.toml` | `skip_selection = true` (straight to password), GTK theme/icons/cursor/font, clock |
| `/etc/greetd/regreet.css` | Catppuccin Mocha styling |
| `/var/lib/regreet/state.toml` | ReGreet's memory of last user + session (`Hyprland (uwsm-managed)`); pre-seeded at install |
| `/etc/greetd/config.toml.orig` | greetd's default config |

- `skip_selection`: boots straight to the password prompt. **Cancel** returns to user/session pickers.
- Preview without logging out (needs `greetd-regreet`):
  `regreet --demo --config <toml> --style <css> --logs /tmp/regreet.log`
  (demo credentials are written to the log).
- Logs: `/var/log/regreet/`, `journalctl -u greetd`.
- If you change monitors in HyprMod, mirror the change in `/etc/greetd/hyprland.lua` (needs sudo).

**Rollback to SDDM** (e.g. black screen at boot: press Ctrl+Alt+F2 and log in on the console):
```
sudo systemctl disable greetd && sudo systemctl enable sddm
```
SDDM is still installed but disabled. Remove it for good with `sudo pacman -Rns sddm`.

## Session startup chain

greetd → ReGreet → session `Hyprland (uwsm-managed)` → **uwsm** starts Hyprland under systemd.
Because of uwsm, the standard XDG autostart directory **works**: files in `~/.config/autostart/`
become `app-<name>@autostart.service` user units.
- Currently there: `OpenRGB.desktop` (`openrgb --startminimized`, created by OpenRGB's own setting).
- systemd reads that folder at session start; after adding a file mid-session, run
  `systemctl --user daemon-reload` to test it immediately.

## Keyring: gnome-keyring

- `gnome-keyring-daemon.socket` (user unit) is enabled. Login keyring: `~/.local/share/keyrings/login.keyring`.
- **Unlocked automatically at login** via PAM: `/etc/pam.d/greetd` has
  `auth optional pam_gnome_keyring.so` and `session optional pam_gnome_keyring.so auto_start`
  (backup `/etc/pam.d/greetd.bak`).
- The greeter user also runs those PAM lines, which logs harmless "unable to create keyring dir:
  /.local/share/keyrings" errors at boot.
- Chromium uses it via `~/.config/chromium-flags.conf`: `--password-store=gnome-libsecret`
  (Chromium doesn't auto-detect the keyring on Hyprland).
- Check: `busctl --user call org.freedesktop.secrets /org/freedesktop/secrets org.freedesktop.Secret.Service ReadAlias s default`
  should return `/org/freedesktop/secrets/collection/login`.

## Polkit (admin password prompts)

- `hyprpolkitagent.service` (user unit), enabled. `polkit-kde-agent` was removed.
- Check: `systemctl --user status hyprpolkitagent`. The journal should say "registered polkit agent".

## Other user units

| Unit | Purpose |
|---|---|
| `hyprpolkitagent.service` | polkit agent |
| `gnome-keyring-daemon.socket` | keyring |
| `paru-aur-completion.timer` | weekly refresh of paru's AUR tab-completion list (see 07) |
| `claude-usage-tray.service` | Claude usage tray icon + menu for the Caelestia bar (see 03) |
| `awww.service` | wallpaper daemon (Caelestia's own wallpaper layer is off; see 03) |
| `themectl-sync.service` | mirrors Caelestia's wallpaper onto awww with the grow transition (see 03) |
| `dunst.service` | **masked**; Caelestia handles notifications |
