# Gaming and Steam

## Install

- Steam comes from the **multilib** repo, enabled in `/etc/pacman.conf` (`[multilib]` + `Include`).
- Installed with `lib32-nvidia-utils` (32-bit NVIDIA driver; needed by many games and launchers).

## Sharp Steam UI (XWayland at 1.25 scale)

- Steam's client is X11-only, so it runs through XWayland. At fractional scale Hyprland used to
  upscale it, which made it blurry.
- `xwayland.force_zero_scaling = true` (qol.lua): X11 apps render natively, so they're sharp but smaller.
- `STEAM_FORCE_DESKTOPUI_SCALING=1.25` (env var in qol.lua) makes Steam scale itself back up.
  Steam must be started from the launcher/keybind (not an old terminal) to get it. You also
  adjusted scaling in Steam's accessibility settings.

## Proton builds from Heroic

- Heroic downloads `GE-Proton-latest` and `Proton-CachyOS-latest` into `~/.config/heroic/tools/proton/`.
- **Symlinked** into Steam: `~/.local/share/Steam/compatibilitytools.d/{GE-Proton-latest,Proton-CachyOS-latest}`.
  Restart Steam to detect new ones.
- Steam shows them by their **internal name** (e.g. `GE-Proton11-11-x86_64`). When Heroic updates
  "latest", that name changes and per-game selections lose their setting; re-pick them.
- **Global default = GE-Proton**: `CompatToolMapping` → `"0"` → `name "GE-Proton11-11-x86_64"` in
  `~/.local/share/Steam/config/config.vdf` (backup `config.vdf.bak`). After a GE update, change it
  in Steam → Settings → Compatibility. To edit the file instead, quit Steam first; it overwrites the file on exit.

## Game picks the wrong (portrait) monitor

- X11/Proton games use XWayland's **primary** output; none was set, so they took the first one
  (the portrait monitor).
- Fix: at login, `qol.lua` runs `xrandr --output <main connector> --primary` (looked up by monitor
  description). Check: `xrandr --listmonitors` shows `*` on the main monitor.
- Native-Wayland games ignore this. Per-game fallback (needs `gamescope`):
  launch options `gamescope --prefer-output DP-6 -f -- %command%`.
- Hyprland also starts focus on the main monitor at login.
- No need to swap DP cables (which would move the boot screen).

## Download speed investigation (2026-10-23)

Symptom: Steam ~100–250 Mbps on a gigabit line that used to give 800–900.

Findings:
- Not the PC. With Steam paused, 8 parallel streams reached **~880 Mbps from OVH over both IPv4 and
  IPv6** on the same NIC/driver. CPU ~6%, no disk wait during Steam downloads.
- Not IPv6 MTU (full 1500-byte packets pass), not the NIC link (1000 Mbps full duplex, no errors).
- One real hardware fault found: a **USB plug jammed into the 1 GbE RJ45 port**. Removing it raised
  speeds to ~500 Mbps.
- What remained looked server/route-side: speed varied by Steam server (Madrid cache vs
  Google/Fastly/Akamai CDNs) and by download region; Paris did better.
- The `steam_dev.cfg` HTTP/2 tweak was tried and then **removed** (not needed before).

If it recurs: try another download region (Settings → Downloads), clear the download cache,
check `~/.local/share/Steam/logs/content_log.txt` ("Current download rate" lines and which CDN
hosts it uses), and measure the NIC live:
`cat /sys/class/net/<iface>/statistics/rx_bytes` twice, 5 s apart.

## Other

- Steam Friends List tiles as a narrow column (window rule, see 01-hyprland.md).
- **Games open in a scratchpad:** `steam_app_*` windows go to `special:games` (rule
  `steam-games-scratchpad`); Super+G shows/hides it. Hiding doesn't pause the game. Launchers with the
  same class land there too; non-Steam games (Heroic, etc.) don't match and open normally. Caelestia's
  bar lists `games` (gamepad icon) in its special-workspace strip only while a scratchpad is open and
  the workspace has windows.
- **Game mode follows the games scratchpad:** `hl.on("window.open"/"window.close")` hooks in `qol.lua` run
  `qs -c caelestia ipc call gameMode enable` when a window opens in `special:games` and `disable` when the
  last one there closes (Caelestia's game mode: no animations, blur, gaps, shadows; tearing allowed; a toast
  each way; disabling runs `hyprctl reload`). Only those two transitions act, so a manual toggle with no game
  open sticks. On `window.close` the closing window is still in `hl.get_windows()`, so compare `.address`.
  Check: `qs -c caelestia ipc call gameMode isEnabled`. Manual toggle: **Super+Shift+G**.
- **No lock/blank mid-game:** Caelestia's idle timeouts (lock 3 min, DPMS off 5 min, a third action at
  10 min) only see keyboard/mouse, not gamepads. Window rules `fullscreen-no-idle` and
  `steam-games-no-idle` set Hyprland idle inhibitors, which Caelestia respects (`respectInhibitors`).
  Verified 2026-10-23 on "Over the Hill" (`steam_app_2929250`, fullscreen): `inhibitingIdle: true`.
  Non-Steam games (Heroic, etc.) are covered only while fullscreen.
- OpenRGB applies its `default` profile (all lights off) at login and exits: `~/.config/autostart/OpenRGB.desktop`
  runs `openrgb --profile default` (set with `openrgb --autostart-enable "--profile default"`). No window, no
  tray icon, nothing left running: the controllers keep the colours on their own (tested 2026-10-25). Opening the
  app normally works as usual. If the lights ever need OpenRGB to stay running, use `--server --profile default`
  (headless SDK server, no tray). Before: `--startminimized` (GUI hidden in the tray).
