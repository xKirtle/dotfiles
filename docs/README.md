# System setup notes

Source of truth for how this Arch + Hyprland machine is configured, written during the
initial setup session (2026-10-23). Each file covers one area: what was changed, where it
lives, why, and how to undo or tweak it.

| File | Covers |
|---|---|
| [01-hyprland.md](01-hyprland.md) | Hyprland config layout, monitors, workspaces, window rules, env vars |
| [02-keybinds.md](02-keybinds.md) | Every custom keybind (cheat sheet) |
| [03-desktop-shell-and-theming.md](03-desktop-shell-and-theming.md) | Caelestia shell, fonts, kitty, GTK/Qt theme, screenshots, file manager |
| [04-login-and-session.md](04-login-and-session.md) | greetd + ReGreet login screen, keyring, polkit, autostart |
| [05-audio.md](05-audio.md) | Scarlett Solo, WirePlumber rules, mic/output shortcuts |
| [06-gaming-and-steam.md](06-gaming-and-steam.md) | Steam scaling, Proton builds, primary monitor, download-speed findings |
| [07-system-and-packages.md](07-system-and-packages.md) | paru, pacman, bash, network, timezone, removed packages |

These notes are `docs/` in the dotfiles repo `~/Dev/Personal/dotfiles` (git + GNU Stow;
`~/Documents/system-setup` is a symlink here). Most configs are symlinks into that repo, so the
paths below still work as written. The repo's `README.md` covers the layout and install.

## Hardware at a glance

- **GPU:** NVIDIA RTX 4090 (`nvidia-open-dkms`) drives both monitors. The CPU's Radeon iGPU is unused for display.
- **Monitors:** two LG ULTRAGEAR+ 4K, both at scale 1.25.
  - Main, landscape, 240 Hz: serial `411NTTQ06481` (currently `DP-6`)
  - Side, portrait (rotated), 144 Hz: serial `402NTJJB7972` (currently `DP-5`)
- **Audio:** Focusrite Scarlett Solo 4th Gen (USB). The other output is the motherboard's S/PDIF (Ryzen HD Audio).
- **Network:** two Realtek ports, 2.5 GbE RTL8125 (`enp8s0`) and 1 GbE RTL8111 (`enp5s0`). Wi-Fi is MediaTek MT7922 (`wlp7s0`).

## Applying changes

| Changed | How to apply |
|---|---|
| `~/.config/hypr/*.lua` | `hyprctl reload`, then `hyprctl configerrors` (empty = OK) |
| Hyprland env vars / `hyprland.start` autostart | log out and back in |
| `~/.config/caelestia/shell.json.template` or `.env` | `./install.sh caelestia` (renders `shell.json`), then restart the shell: **Ctrl+Super+Alt+R** (only read at startup) |
| `~/.config/wireplumber/…` | `systemctl --user restart wireplumber` (≈1 s audio blip) |
| `/etc/greetd/*` | takes effect at next login screen (log out / reboot) |
| Steam `config.vdf` / `steam_dev.cfg` | quit Steam fully first (it overwrites `config.vdf` on exit) |

## Gotchas learned the hard way

- **Hyprland here uses the Lua config (0.55+).** Hyprlang snippets from older guides don't apply.
  - `hyprctl keyword …` doesn't work. Use `hyprctl eval '<lua>'` for live changes, e.g.
    `hyprctl eval 'hl.config({ input = { sensitivity = -0.4 } })'`.
  - Dispatch from the shell with `hyprctl dispatch 'hl.dsp.….(...)'`.
  - Window-rule sizes do **not** accept `"20% 60%"`; it's silently ignored. Use expressions:
    `size = "monitor_w*0.2 monitor_h*0.6"`.
  - Validate a config file without running it: `Hyprland --verify-config --config <file>`.
- **HyprMod owns `~/.config/hypr/hyprland-gui.lua`** and rewrites it on save. Don't hand-edit it;
  put manual settings in `qol.lua`, which loads after it and can override it.
- **Super+M used to be "exit Hyprland"** (default config). It's rebound to maximize; log out via Super+Esc.
- **Connector names (`DP-5`, `DP-6`) can change** after driver updates or moving cables. Configs refer
  to monitors by description (`desc:LG Electronics LG ULTRAGEAR+ <serial>`), except HyprMod's file.

## Backups made during setup

- `~/.dotfiles-pre-stow/`: every config as it was right before the switch to stow symlinks
  (2026-10-24), same paths, plus the notes folder (`system-setup-notes/`)
- `~/.config/hypr/hyprland.lua.bak`: the original auto-generated Hyprland config
- `~/.bashrc.bak`: original `.bashrc`
- `/etc/greetd/config.toml.orig`: greetd's default config
- `/etc/pam.d/greetd.bak`: login config before the keyring lines
- `~/.local/share/Steam/config/config.vdf.bak`: Steam config before setting GE-Proton as default
