# Agent context: this Arch + Hyprland desktop

You're helping maintain the user's personal workstation. The detailed, authoritative notes are the
Markdown files in this directory. Read `README.md` first, then the topic file for the area you're
touching, **before** changing anything:

- `01-hyprland.md`: config layout, monitors, workspaces, window rules, env vars, Lua API notes
- `02-keybinds.md`: every keybind
- `03-desktop-shell-and-theming.md`: Caelestia shell, fonts, kitty, GTK/Qt, screenshots, Thunar
- `04-login-and-session.md`: greetd + ReGreet, uwsm, keyring, polkit, autostart
- `05-audio.md`: Scarlett Solo 4th Gen, WirePlumber rules, audio shortcuts
- `06-gaming-and-steam.md`: Steam scaling, Proton, primary monitor, download-speed findings
- `07-system-and-packages.md`: paru workaround, pacman, bash, network
- `08-calendar.md`: Proton Calendar sync (vdirsyncer/khal), reminders, agenda panel (`calendarctl`)
- `09-vpn.md`: Proton VPN CLI, VPN panel (`vpnctl`), Caelestia VPN toggle
- `10-system-monitor.md`: system monitor / task manager panel (`sysmonctl`, Ctrl+Shift+Esc)

## Dotfiles repo

- These notes are `docs/` of the dotfiles repo **`~/Dev/Personal/dotfiles`** (git, GNU Stow);
  `~/Documents/system-setup` is a symlink to it. Most configs are stow symlinks into the repo, many
  as **whole folders** (`~/.config/hypr → dotfiles/hypr/.config/hypr`), so editing the usual
  `~/.config/...` path edits the repo. Layout and install: the repo's `README.md`.
- **New config files:** add them to the matching package (or a new one) and re-run `./install.sh <pkg>`;
  if an app generates files inside a linked folder, add them to `.gitignore`. `/etc` files are
  reference copies in `system/` (update the copy after changing the real file).
- **Private values** (town, calendar URL, ...) live in the repo-root **`.env`** (gitignored; placeholders in
  the tracked `.env.example`). The repo is **public**: never commit them. Apps that can't read env vars get a
  tracked `<file>.template` with `${VAR}` placeholders; `./install.sh <pkg>` renders it to `<file>` with
  `envsubst` (only the variables `.env` defines) before stowing, and the rendered file is gitignored. Edit the
  template, never the rendered file (e.g. Caelestia's `shell.json`). Scripts can read `.env` at run time
  instead (`calendarctl url` for vdirsyncer's `url.fetch`).
- **Edit file-level links through the repo path.** `~/.local/bin/*`, `~/.config/systemd/user/*`,
  `~/.bashrc` etc. are single-file symlinks: `sed -i` on them replaces the link with a plain file
  (cut loose from the repo), and the Edit tool refuses to write through them. Edit
  `~/Dev/Personal/dotfiles/<pkg>/...` instead. Files inside folder-linked dirs (`~/.config/hypr/...`) are fine.
- Commit or push only when the user asks. Pre-stow originals: `~/.dotfiles-pre-stow/`.
- `claude-usage-tray` is its own repo (`~/Dev/Personal/claude-usage-tray`, installed via its `install.sh`).

## Ground rules

- **Keep these notes current.** After any change, update the matching topic file (and
  `02-keybinds.md` for binds) in the same session. The user relies on them as the source of truth.
- **Verify, don't assume.** Check live state (`hyprctl`, `wpctl`, `pw-dump`, `systemctl --user`,
  `pacman -Q`) before and after changes; the notes can drift from reality. If they disagree, trust
  the live system and fix the notes.
- **No passwordless sudo.** For anything needing root (`/etc`, pacman, system services), write files
  to a scratch location, verify them, and give the user the exact command to run.
- **Never connect, disconnect or switch the VPN yourself:** it kills your own API connection mid-reply
  (the session hangs until the user writes again). Ask the user to do it (`09-vpn.md`).
- **Say before you disrupt.** Restarting WirePlumber (audio blip), the Caelestia shell, Steam, or
  NetworkManager connections affects what the user is doing. Mention it, and avoid it mid-download.
- Back up a file before overwriting anything that isn't already documented as ours.
- The user prefers concise answers, a clear recommendation over a survey, and small, reviewable
  shell commands (they've asked to split long one-liners).

## Hyprland specifics (Lua config, 0.55+)

- Put changes in `~/.config/hypr/qol.lua`. **Never hand-edit `hyprland-gui.lua`**: HyprMod rewrites it.
  `hyprland.lua` holds input settings (layouts, sensitivity, accel) and loads `hyprland-gui` then `qol`.
- Apply and check: `hyprctl reload` then `hyprctl configerrors` (empty = OK).
  Validate a standalone file: `Hyprland --verify-config --config <file>`.
- `hyprctl keyword` doesn't work. Use `hyprctl eval '<lua>'` and `hyprctl dispatch 'hl.dsp.…'`.
- Window-rule `size` needs expressions (`"monitor_w*0.2 monitor_h*0.6"`); `"20% 60%"` is silently ignored.
- Refer to monitors **by description** (`desc:LG Electronics LG ULTRAGEAR+ <serial>`), not `DP-x`:
  main/landscape `411NTTQ06481`, portrait `402NTJJB7972`.
- Workspaces 1–5 = main monitor, 6–10 = portrait (scrolls vertically, arrow binds rotated 90°).
- `hl.on("hyprland.start", …)` runs only at login, not on reload.
- Overriding a default bind: `hl.unbind(key)` first, else both fire. Check with `hyprctl binds -j`.
- Give every bind `{ description = "Group: what it does" }`: the Super+K keybinds panel shows it (03).

## Testing tricks that worked

- Test window rules/layouts with throwaway windows: `setsid -f kitty --class qoltest1 -e sleep 30`,
  move them with `hl.dsp.window.move({ workspace = "6", window = "address:…", silent = true })`,
  inspect with `hyprctl clients -j`, then close them and restore focus to the user's previous window.
- Runtime-only rules for experiments: `hyprctl eval 'hl.window_rule({...})'` (cleared by `hyprctl reload`).
- Don't `pkill -f <pattern>` with the pattern in your own command line; it matches your own shell.
  Use `pgrep -x <name>` or window addresses.
- Caelestia picks up most `shell.json` changes live (bar options did, 2026-10-25). If one doesn't show, restart:
  `qs -c caelestia kill; for i in $(seq 50); do pgrep -f '^qs -c caelestia' >/dev/null || break; sleep 0.1; done; caelestia shell -d`
  (launch via `hyprctl dispatch 'hl.dsp.exec_cmd("…")'` so it outlives your shell). Don't wait on
  `pgrep -x qs`: other Quickshell configs (claude-usage, theme-picker) run too. Afterwards confirm a new
  PID with `pgrep -af '^qs -c caelestia'`; if the bar is gone, run `caelestia shell -d` again.
- Serein (Discord) reads its theme store only at startup: `themectl sync` regenerates its "Caelestia" theme,
  but don't restart Serein to check (the user chats in it); validate packages with Serein's own crate
  (`03-desktop-shell-and-theming.md`, Serein).
- Panels are toggled/started by `~/.local/bin/qs-panel` (shared scale, `03`).
- The Quickshell panels (`qs -c claude-usage`, `qs -c theme-picker`, `qs -c agenda`, `qs -c keybinds`, `qs -c sysmon`) don't live-reload: `qs -c <name> kill`,
  then they restart on next use. Processes they start get the session PATH, which lacks `~/.local/bin`,
  so use absolute paths.

## Machine facts

- NVIDIA RTX 4090 (`nvidia-open-dkms`) drives both 4K monitors at scale 1.25; uwsm-managed Hyprland session.
- Shell: bash (not zsh/fish) with starship, fzf, zoxide, eza, bat.
- AUR helper: paru (see `07-system-and-packages.md` for its completion workaround).
- Colours: dynamic from the wallpaper, picked with themectl (Super+Ctrl+Space; `03-desktop-shell-and-theming.md`).
