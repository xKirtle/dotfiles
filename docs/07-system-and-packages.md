# System and packages

## paru

- `~/.config/paru/paru.conf` = copy of `/etc/paru.conf` + `CompletionInterval = 36500`.
  paru reads this file **instead of** `/etc/paru.conf`, so future paru settings go here.
- **Why:** paru 2.1.0 writes a corrupt AUR package list (`~/.cache/paru/packages.aur`) when it
  refreshes it, which breaks `paru -S <tab>` completion for AUR packages. Its own refresh is pushed
  out ~100 years; `-1` ("never") is documented but **rejected** by the parser ("invalid digit").
- Replacement refresh: `~/.local/bin/paru-aur-completion-refresh` (downloads
  `aur.archlinux.org/packages.gz`, unpacks, sanity-checks), run weekly by
  `paru-aur-completion.timer` (user unit).
- **Undo once paru is fixed:** delete the `CompletionInterval` line, then
  `systemctl --user disable --now paru-aur-completion.timer`.
- Tab completion needs `bash-completion` (sourced in `.bashrc`).
- Build leftovers (`rust`, `cmake`, `meson`, …) are orphans you can remove with
  `sudo pacman -Rns $(pacman -Qdtq)`; paru reinstalls them when needed.

## pacman

- `[multilib]` enabled (for Steam).
- `Color` and `ParallelDownloads = 5` were already set.
- `paccache.timer` enabled: weekly cache cleanup, keeps the last 3 versions.

## bash (`~/.bashrc`, backup `~/.bashrc.bak`)

Appended section `# ---- QoL ----`:
- bash-completion; history 50k/100k, deduped, shared across terminals; `autocd`, `globstar`, `cdspell`
- `EDITOR=nano`; `MANPAGER` uses bat
- aliases: `ls`/`ll`/`la`/`lt` → eza, `cat` → bat, `..`, `...`, `update` = `paru -Syu`
- fzf keybinds (Ctrl+R history, Ctrl+T files, Alt+C dirs) with Catppuccin colours, using fd
- `zoxide` (`z <dir>`), `starship` prompt (`~/.config/starship.toml` = `catppuccin-powerline` preset)
- bat theme: `~/.config/bat/config` → `Catppuccin Mocha`
- aliases `dotfiles` / `bandmate`: `cd` into that repo and start `claude`
- `SONARQUBE_TOKEN` is exported from the repo `.env` at shell start (only that key is
  read; the token never goes in `.bashrc`). Change it in `.env`, then open a new terminal.

## Network

- Ports: 2.5 GbE RTL8125 `enp8s0` and 1 GbE RTL8111 `enp5s0`, both `r8169` driver. In use at
  setup end: `enp5s0` (1 GbE). Gigabit internet, so either port is fine.
- Wi-Fi (`wlp7s0`, MT7922) is off: `nmcli radio wifi off` (`on` to re-enable).
- IPv6 is on everywhere (a temporary `disable_ipv6` test was reverted).
- Firewall: `ufw` (enabled before this session).
- **Proton VPN:** official CLI (`protonvpn`) + VPN panel (Super+Shift+P): `09-vpn.md`.

## Time and locale

- Timezone `Europe/Lisbon` (`timedatectl`); NTP via `systemd-timesyncd`.

## Docker

- Packages: `docker`, `docker-compose`, `docker-buildx`. `docker.service` and `docker.socket` are
  enabled (daemon starts at boot).
- User is in the `docker` group (`sudo usermod -aG docker $USER`, 2026-10-26), so `docker` works
  without sudo. Takes effect after re-login; this group is root-equivalent (rootless Docker was
  the alternative, not used).

## Removed / disabled

| What | Why |
|---|---|
| `dolphin` | replaced by Thunar |
| `file-roller`, `thunar-archive-plugin` | replaced by our Thunar archive actions (see 03) |
| `polkit-kde-agent` (+ 7 KDE libs) | duplicate of `hyprpolkitagent` |
| `sddm` (disabled, still installed) | replaced by greetd |
| `dunst` (masked, still installed) | Caelestia handles notifications |

## Extra tools installed

`alsa-utils`, `alsa-scarlett-gui` (AUR), `7zip`, `gnome-keyring`, `hyprpicker`, `trash-cli`, `mpv`, `imv`, `fuse-archive` (AUR), `fuse-overlayfs`,
`playerctl`, `nwg-look`, `qt6ct`, `kvantum`, `python-cairo` (missing dependency of HyprMod's
monitor view; marked as a dependency), `whisper-cpp` + `ggml-vulkan` + `wtype` (dictation, see 05).
