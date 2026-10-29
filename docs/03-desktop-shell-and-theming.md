# Desktop shell and theming

Theme everywhere: **Catppuccin Mocha**.

## Caelestia shell

- Packages: `caelestia-shell`, `caelestia-cli` (AUR; pulls `quickshell-git`, built from source).
  Only the packages were installed; Caelestia's dotfiles installer was **not** run, because it
  would overwrite the Hyprland config.
- Started by `qol.lua` autostart (`caelestia shell -d`). Restart: **Ctrl+Super+Alt+R**. That bind
  waits for the old instance to exit before starting a new one; a too-short wait leaves you with no bar
  (the new instance sees the old one and quits). It waits on `pgrep -f '^qs -c caelestia'`, **not**
  `pgrep -x qs`: other Quickshell configs run too (claude-usage, theme-picker), which would make
  `-x qs` wait the full 5 s every time. The `^` stops the pattern from matching the bind's own `sh -c`
  line, and the pattern also skips the `[qs] <defunct>` zombie a killed instance can leave behind.
  Confirm with a new PID: `pgrep -af '^qs -c caelestia'`. If the bar is gone, run `caelestia shell -d`.
- **Config:** `~/.config/caelestia/shell.json`. Bar options (e.g. `bar.popouts`) apply live once `shell.json` is re-rendered; restart the shell if a change doesn't show.
  It's **generated**: edit `shell.json.template` (tracked) and re-render with `./install.sh caelestia`
  from the repo; private values (`${WEATHER_LOCATION}`) come from the repo's gitignored `.env`
  (README: "Private values"). `shell.json` itself is gitignored, and anything written straight into it
  (by hand or Caelestia's settings app) is lost on the next render, so copy such changes into the template.
  Full option reference: README of <https://github.com/caelestia-dots/shell>. Current contents:
  - `bar.statusIcons`: lockStatus, **microphone**, **kbLayout**, network, bluetooth, battery enabled; audio off.
    It's an array, so list all entries, not just the changed ones.
  - `osd.enableMicrophone: true`: popup on mic volume/mute changes.
  - `bar.clock.showDate: true`: date next to the bar clock.
  - `bar.popouts.activeWindow: false`: no popout when hovering the active-window title in the bar.
  - `bar.workspaces.specialWorkspaceIcons`: `games` → `sports_esports` (gamepad), `magic` (Super+S scratchpad) → `auto_awesome` (sparkles). The strip of special
    workspaces only shows while one is open, and lists only non-empty ones.
  - `utilities.quickToggles`: the drawer's default buttons (wifi, bluetooth, mic, settings, gameMode, dnd)
    plus **vpn**, which is off by default. Setting the list replaces the defaults, so keep all of them listed.
  - `utilities.vpn`: enabled, one provider `proton` (selected): the toggle runs `/usr/bin/protonvpn
    connect|disconnect` (fastest server) and reads state from the `proton0` interface. Caelestia has no Proton
    adapter; this is the generic custom-provider form (`09-vpn.md`). `selectedProvider` comes from the
    template, so a re-render resets a choice made in the settings app.
  - `launcher.useFuzzy.apps: true`: fuzzy app matching in the launcher.
  - `lock.hideNotifs: true`: no notification contents on the lock screen.
  - `notifs.actionOnClick: true`: clicking a notification runs its default action (not just dismiss).
  - `utilities.toasts.nowPlaying: true`: toast on track change.
  - `services.weatherLocation: "${WEATHER_LOCATION}"` (the town is set in `.env`, kept out of the public
    repo), `services.weatherUnits: "celsius"` (enum is Auto/Celsius/Fahrenheit/Kelvin; lowercase name
    works). A place name goes to Open-Meteo's geocoder, which uses the **first match only**, so add the
    region ("Town, Region") if the name is ambiguous; `"lat,lon"` also works.
    Empty falls back to ip-api.com, which was refusing connections here.
  - `background.wallpaperEnabled: false`: Caelestia doesn't draw the wallpaper; awww does (see
    "Themes and wallpapers" below). Its background layer stays, transparent, for the desktop clock and visualiser.
    Backup from before this change: `shell.json.bak-pre-awww`.
  - Other defaults (2.5.0) left off on purpose: `general.showOverFullscreen` (gaming), `background.visualiser`,
    `background.desktopClock`, `appearance.transparency`, `launcher.enableDangerousActions`, VPN toggle.
- **Reading the effective config** (defaults are compiled into the plugin, not in any file): run a
  throwaway Quickshell script that imports `Caelestia.Config`, walks the `GlobalConfig` singleton
  and `console.log`s each value, e.g. `timeout 8 qs -p dump/shell.qml > out.txt 2>&1` (it never quits
  on its own). Option names are in `/usr/lib/qt6/qml/Caelestia/Config/caelestia-config.qmltypes`.
- **Colour scheme:** normally dynamic, set by the themectl wallpaper picker (below); by hand:
  `caelestia scheme set -n catppuccin -f mocha -m dark`, or `-n dynamic` for wallpaper-based colours.
  - **How it works:** `caelestia-cli` (Python). Named schemes are fixed palettes shipped with it.
    `dynamic` takes a seed colour from the wallpaper thumbnail with `python-materialyoucolor` (Google's
    Material Color Utilities, the same algorithm as matugen) and builds a Material 3 palette plus 16
    terminal colours (`variant` = tonalspot/vibrant/…). Result: `~/.local/state/caelestia/scheme.json`.
  - **What follows it:** Caelestia's shell and our Quickshell panels (live, from `scheme.json`); template
    files for btop, htop, nvtop, fuzzel, cava, Discord, Spicetify,
    Zed, Warp; **Qt apps** (our `templates/qt6ct.conf`, see GTK / Qt theming; on app restart);
    **running terminals** (it writes OSC colour sequences to every `/dev/pts/*`);
    **new terminals** (our `~/.bashrc` runs `command cat ~/.local/state/caelestia/sequences.txt`; `command`
    because `cat` is aliased to `bat`, which adds a "File:" header; backup
    `.bashrc.bak-pre-sequences`); **Hyprland borders**, **Chromium**, **Serein**, **VS Code**, **GTK** (Thunar etc.) and the
    **folder icons** (via `themectl sync`, see below and "GTK / Qt theming"; Serein and GTK 4 apps only
    after a restart, the rest live); **Spotifast** (live, see next point).
    Custom templates for other apps can go in `~/.config/caelestia/templates/` (`{{ primary.hex }}`-style
    fields, also `.hexalpha`/`.rgb`/`.hsl` and `{{ mode }}`; an unknown name is left unfilled; written to
    `~/.local/state/caelestia/theme/<same name>`). After rendering, Caelestia runs `theme.postHook` from
    `~/.config/caelestia/cli.json` (tracked; it's a single shell string, so chain any new hook onto it).
  - **Spotifast** (Spotify client): palettes are `~/.config/spotifast/themes/<Name>.json`
    (`{"base": "dark|light", "colors": {window, panel, surface, surface_hover, surface_active, outline,
    text, secondary, dim, accent, accent_hover, on_accent, danger, warning, overlay, shadow, tint}}`,
    `#RRGGBB[AA]`, omitted keys inherit; **no symlinks**). Template `templates/spotifast.json`; the
    postHook runs `~/.local/bin/spotifast-caelestia-theme` (`spotifast` package), which validates the
    render and copies it atomically to `themes/Caelestia.json` (modelled on the Omarchy hook in
    `/usr/share/spotifast/omarchy/`), then runs `spotifast reload-themes`. Spotifast's inotify watcher
    also reloads it live without interrupting playback. Select it once in Settings > Appearance > Theme >
    **Caelestia** (stored as `custom_theme` in `settings.json`; don't edit that while it runs). With
    "accent from album art" on, album art may still override the accent.
  - **What doesn't:** running Qt apps (they read the palette at startup). kitty's own
    `catppuccin-mocha.conf` is just the base the sequences override.
  - Caelestia's own Hyprland output (`~/.config/hypr/scheme/current.lua`) is read by `qol.lua` at load
    (border block, with a Catppuccin fallback). Its own Chromium output needs passwordless sudo and
    always fails here.
- **Wallpapers:** use the themectl pickers (below). Caelestia's own launcher `>wallpaper` and
  `caelestia wallpaper -f <file>` still work and still get the awww transition, but they don't
  change the theme. Caelestia's picker misbehaves with exactly two images.
- **Notifications:** Caelestia is the notification daemon. `dunst` is installed but **masked**
  (`systemctl --user unmask dunst` to undo).
- **Toasts:** Caelestia shows its own "audio output changed" toast (bottom right); that's why the
  audio-switch script doesn't notify. Toggle: `utilities.toasts.audioOutputChanged`.
- No option to move the bar off the left edge; it's built vertical.
- Logs of the running instance: `/run/user/1000/quickshell/by-id/*/log.qslog` (binary-ish; use `strings`),
  plain-text copy `log.log` next to it; `by-pid/<pid>` links to the instance's folder.
- **Lock screen crashes when the monitors drop off while locked** (2026-10-25). After DPMS off the LGs go
  into deep sleep and drop their DisplayPort link (`Connector DP-5 disconnected` in `hyprland.log`). On wake,
  Hyprland logs `error in client communication (pid <shell>)`, disconnects the shell, and shows its
  "lockscreen crashed" screen. Unlocked, the shell survives one or both monitors going off and on (tested).
  Fix: **deep sleep turned off in both monitors' OSD** (2026-10-25), so they stay connected while off.
  Recovery: **Super+Ctrl+Shift+L** (restarts the shell and calls `caelestia shell lock lock`; works because
  `misc.allow_session_lock_restore = true` in `qol.lua`). Last resort from a tty:
  `hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'`. A dead shell shows no bar until restarted.
- Test-run in the foreground to see errors: `timeout 8 qs -c caelestia -n`.
- **Keep awake** (idle inhibitor): **Super+Shift+I** toggles it and notifies the new state; CLI
  `caelestia shell idleInhibitor toggle|enable|disable|isEnabled`. Only on-screen indicator: the
  "Keep awake" card in the utilities drawer ("Preventing sleep mode", "Active since …"); no bar icon.
- **No plugin system yet** (2.5.0): Nexus has a "Plugins" entry, but `AboutPage.qml` says it isn't
  wired up. Bar entries are a fixed list (logo, workspaces, activeWindow, tray, clock, statusIcons,
  power), so custom bar widgets go through the **tray** (any StatusNotifierItem shows there; hovering
  opens its D-Bus menu as a popout; there are no tooltips). A copy in `~/.config/quickshell/caelestia`
  would override the packaged shell, but that's a fork that stops getting pacman updates.

## Wallpapers and colours (ours)

Every wallpaper gets its **own dynamic colour scheme** (Caelestia's `dynamic`, from the image). Wallpapers
live in `~/Pictures/Wallpapers/`, loose or in subfolders; **folders are only for grouping**. (Until
2026-10-26 a folder was an Omarchy-style *theme* with a fixed named scheme; the theme and per-theme wallpaper
pickers were replaced by the one below. The folders were flattened at the same time; `test/` holds copies
of five root images.)
- **Picker: Super+Ctrl+Space** (`~/.config/quickshell/theme-picker/shell.qml`, its own Quickshell config, a
  full-screen overlay on the focused monitor; `themectl picker` toggles it). Browses the folder like a file
  manager: the top level shows the **folders first** (a collage of their first 1–4 wallpapers, a folder icon
  and a count badge), **then the loose images**.
  - **Enter (or click)** on a folder opens it (always, even with one wallpaper); on a wallpaper applies it
    (`themectl wall <file>`). **Esc/Backspace** goes back, or closes at the top level (so does a click outside).
    **R** applies a random wallpaper from the view (the open folder, or all of them at the top level), never
    the current one. Arrows/hjkl move.
  - **Swatches** on each wallpaper tile = the scheme it would make: `themectl list --json --dynamic`
    (`wallpaper_swatches`) computes them with Caelestia's own `get_colours_for_wall` (what
    `caelestia wallpaper -p <file>` prints, smart light/dark and variant included; cached by Caelestia in
    `~/.cache/caelestia/`). Folders show none. The loose images come as the `unsorted` entry with `"root": true`.
  - **Listing speed** (`themectl list --json --dynamic`, warm caches: ~75 ms, was ~210 ms): `--dynamic` skips
    `theme_scheme` (it ran `caelestia scheme list`, ~75 ms, for nothing), and Caelestia's SHA-256 of each
    whole image (its cache key, ~50 ms per listing) is memoised in `~/.cache/themectl/hashes.json` by
    path + size + mtime (`memo_compute_hash` patches `compute_hash` in Caelestia's modules). The rest is
    importing the `caelestia` package (~45 ms; its `__init__` loads the whole CLI). A Go rewrite was
    benchmarked (2026-10-27) and wasn't worth it: the time is in Caelestia/khal/the kernel, not Python.
  - **Size:** up to 4 columns; rows visible = screen height (logical) / 432, so **4×4** on the main monitor
    (1728 px tall at scale 1.25) and 7 rows on the portrait one. More **scrolls** (wheel, or it follows the
    keyboard selection), with a thin position bar on the right.
  - **Thumbnails:** tiles load small JPEGs (≥560×320) that `themectl list` makes once per wallpaper in
    `~/.cache/themectl/thumbs/` (keyed on path + size + mtime; ~30 KB each). Decoding the full 4K–6K
    originals (14 files, 109 MB) took ~1 s per open. A new image adds ~0.15 s (thumbnail) + ~0.2 s (colours)
    to its first listing (all 15 cold: ~2.4 s); if a listing takes over 250 ms the picker shows a spinner
    ("Preparing new wallpapers…"). To see it: `rm -r ~/.cache/themectl/thumbs`, then open the picker.
  - Colours follow `scheme.json`. It doesn't live-reload: `qs -c theme-picker kill` after editing (the next
    bind press restarts it). Qt's JS engine lacks some modern methods (`Array.flatMap` broke the grid once):
    check `qs -c theme-picker log` after opening it.
  - It calls `~/.local/bin/themectl` by **absolute path**: the session PATH (Hyprland/uwsm) lacks
    `~/.local/bin`, so a bare `themectl` fails ("Process failed to start" in `qs -c theme-picker log`).
- **`~/.local/bin/themectl`** (Python): `list [--json] [--dynamic]`, `wall <file>`, `set <theme> [file]`,
  `current`, `picker`, `sync`, `vscode`. State: `~/.local/state/themectl/current.json` (`dynamic: true` after
  `wall`). `THEMECTL_WALLPAPERS=<dir>` points it at another folder (handy for testing).
  `wall` runs `caelestia wallpaper -f <file>`, then `caelestia scheme set -n dynamic` if the scheme isn't
  dynamic yet.
  - **Named schemes (CLI only now):** `list`/`set` still treat folders as themes: scheme from the folder name
    (`<scheme>` or `<scheme>-<flavour>`, e.g. `catppuccin-mocha`; or a `scheme` file in the folder,
    `"<scheme> [flavour] [dark|light]"`), anything else dynamic. `set` runs `caelestia scheme set …`, then
    `caelestia wallpaper -f <file> -N` (`-N` = don't auto-switch light/dark). For a one-off named palette
    without folders: `caelestia scheme set -n catppuccin -f mocha`. Caelestia's "catppuccin mocha" isn't the
    real palette (primary `c2c1ff`, not mauve `cba6f7`); gruvbox-hard is similarly Material-ised.
- **Transitions:** Caelestia's wallpaper layer is off (`background.wallpaperEnabled: false`).
  **awww** draws the wallpaper (`awww.service`). `themectl sync` (`themectl-sync.service`, bound
  to awww) watches `~/.local/state/caelestia/wallpaper/path.txt`, so **every** wallpaper change gets the
  animation, including ones from Caelestia's own picker. It runs one `awww img -o <monitor>` per monitor:
  **grow** from the cursor on the cursor's monitor and from the centre on the others, 1.4 s, at each
  monitor's refresh rate. awww positions are fractions measured from the **bottom**-left. Startup
  (and login) shows the current wallpaper without an animation.
  It also watches `~/.local/state/caelestia/scheme.json`. On change it live-applies **Hyprland
  borders** (`hyprctl eval`, primary → tertiary, inactive = outlineVariant; same mapping as `qol.lua`,
  keep them in step) and writes **Chromium's theme policy**
  `/etc/chromium/policies/managed/caelestia.json` (`BrowserThemeColor` = surface). That only works if
  the dir is user-writable (one-time `sudo install -d -o username -g username /etc/chromium/policies/managed`),
  and it only runs `chromium --refresh-platform-policy` if Chromium is already running (otherwise that
  flag starts a hidden instance). Side effect: Chromium shows "Managed by your organization".
  It also writes a **Serein** theme (`serein_theme`, see "Discord client: Serein" below) and the
  **VS Code** theme (`vscode_theme`, see "VS Code" below), and rebuilds the **folder icons**
  (`papirus_folders`, see "GTK / Qt theming").
  Caelestia writes `scheme.json` **atomically** (temp file + `os.replace`), which arrives as a
  RENAMED event whose *destination* is the watched file; the watcher matches both ends. To test,
  rewrite it the same way (a plain `cat >` only exercises the in-place path).
  The service's memory peak is ~470 MB, from `awww img` decoding the 5K/6K PNGs; it's short-lived.
  Check: `awww query`; logs: `journalctl --user -u themectl-sync`.
  The unit needs `After=graphical-session.target` as well as `After=awww.service`: without it the target's
  implicit ordering after its wanted units forms a cycle with awww (`After=graphical-session.target`), and
  systemd silently drops themectl-sync at login ("Found ordering cycle" in the journal). Fixed 2026-10-26.

## Discord client: Serein

`serein-bin` (AUR nightly, native Rust/egui client, window class `cz.viceverse.serein`).
- **Data:** `~/.local/share/serein/` (`client.sqlite3` = settings, logins, cache; `extensions/`). No
  `~/.config/serein`. Upstream docs: `docs/theme-api.md` and `docs/extensions.md` in
  github.com/ViceVerse-cz/Serein (the package only ships the README).
- **Themes:** JSON, no CSS. Each installed theme is `extensions/themes/<id>/package.json` =
  `{"local_theme", "package": {"manifest", "theme": {"light"|"dark": {"colors", "backdrop"}, "style"}},
  "grants", "reviewed", "sha256", "download_bytes"}` (all `deny_unknown_fields`). The selection is
  `extensions/themes/active.json`, holding just the id (no newline). At most 8 themes. Colour keys
  (`#RRGGBB[AA]`): `base sidebar chat raised hover selected border text_strong text muted link accent
  accent_text positive warning danger mention_bg mention_text`; `style` = font sizes, radii, control
  height. Settings > Themes: Use theme / Create theme / Disable; **Ctrl+Shift+F12** resets to built-in.
  A custom accent in Appearance (`primary_color`) overrides the theme accent.
- **No live reload:** it reads the store only at startup (and on logout/account switch); no inotify, and
  plugins can't read files. A changed theme shows after **quitting and restarting Serein**.
- **Ours: theme "Caelestia"** (`caelestia-scheme`, a local theme), written by `themectl sync`
  (`serein_theme` in themectl) on every `scheme.json` change, the same palette in light and dark:
  base = surfaceContainerLowest, sidebar = surface, chat = surfaceContainerLow, raised =
  surfaceContainer, hover/selected = surfaceContainerHigh/Highest, border = outlineVariant, text_strong =
  onSurface, text = onSurfaceVariant, muted = outline, link = tertiary, accent/accent_text =
  primary/onPrimary, positive = success, warning = yellow, danger = error, mention = primary (bg at 15%).
  `active.json` was switched to it (backup `active.json.bak-pre-scheme`, was `black-theme`).
  **BlackTheme** stays installed: Settings > Themes > BlackTheme > Use theme to go back. Editing
  "Caelestia" inside Serein works but is overwritten on the next scheme change.
- **Checking a package:** Serein's own parser: clone the repo, add an example to `crates/extensions` that
  deserialises the stored record and calls `Package::validate()`, `cargo run -p extensions --example …`.

## VS Code

`visual-studio-code-bin` (Microsoft build; data `~/.config/Code`, extensions `~/.vscode/extensions`).
- **Ours: theme "Caelestia"**, a local extension `themectl.caelestia-theme`. **`themectl vscode`**
  builds a minimal VSIX in a temp dir, installs it with `code --install-extension --force`, and writes the
  current colours (one-time per machine, or to reinstall). VS Code ignores extension folders it didn't install
  (they must be in `extensions/extensions.json`), hence the VSIX. Then pick it once: Ctrl+K Ctrl+T >
  **Caelestia** (or **Caelestia Light**: same file, `vs` base, for light schemes).
- **Live updates:** `themectl sync` (`vscode_theme`) rewrites
  `~/.vscode/extensions/themectl.caelestia-theme-*/themes/caelestia.json` atomically on every `scheme.json`
  change. The theme entries set the undocumented `"_watch": true`, so VS Code watches that file and reloads
  the theme in open windows (checked in 1.143's `workbench.desktop.main.js`: `ThemeFileWatcher` watches when
  `theme.watch || isExtensionDevelopment`). If a VS Code update drops `_watch`, use "Developer: Reload Window".
- **Mapping:** UI = the Serein roles (editor = surface; sidebar, panel, tabs strip, terminal =
  surfaceContainerLow; activity/title/status bar = surfaceContainerLowest; widgets, menus = surfaceContainer;
  hover/selection = surfaceContainerHigh/Highest; borders = outlineVariant; accents, buttons, badges, cursor =
  primary; links, find matches = tertiary). Syntax = Caelestia's named colours with Catppuccin's mapping
  (keywords mauve, strings green, numbers/constants peach, functions blue, types yellow, params maroon,
  properties lavender, comments overlay1), falling back to term/Material colours if a scheme lacks them.
  Integrated terminal ANSI = term0–15 (same as kitty). The theme's `type` follows surface brightness.
- **Checking:** every `colors` key should exist in `/usr/share/code/resources/app/out/vs/workbench/workbench.desktop.main.js`
  (or `extensions/*/package.json`, e.g. `gitDecoration.*` from the git extension); unknown keys are silently ignored.
  Isolated test install: `code --extensions-dir <tmp> --user-data-dir <tmp2> --install-extension …`.

## Panel launcher and scale: `qs-panel` (ours)

`~/.local/bin/qs-panel <config> <ipc target> [toggle args…]` (`qs-panel` package) toggles one of the Quickshell
panels, or starts it (`qs -c <config> -d`) and toggles it open once its IPC answers (~0.3 s). Used by Super+K
(keybinds), `calendarctl panel` (agenda), `vpnctl panel` (VPN) and `sysmonctl panel` (system monitor, 10).

- **Panels stay resident** (hidden, not quit) on purpose. Measured 2026-10-27: an open takes ~55-65 ms when
  the panel is running vs ~170-235 ms from cold (agenda/sysmon/picker); quitting on close would free ~365 MB
  PSS for the three (each fresh qs is ~110-140 MB; the picker grows as thumbnails load). Not worth it on 31 GB.
  The start-up loop retries the IPC every 20 ms (each `qs ipc call` is itself ~30 ms); `themectl picker` matches.
  That cut cold opens from ~305/313/194 ms (agenda/sysmon/picker, 0.1 s retries) to ~224/233/170 ms.

- **Panel scale: `SCALE=1.25` at the top of `qs-panel`.** Also set for the claude-usage panel (its own repo, so
  it takes a flag): `~/.config/systemd/user/claude-usage-tray.service.d/panel-scale.conf` (`qs-panel` package)
  runs the tray with `--panel-scale 1.25`; change both together, then `systemctl --user daemon-reload` and
  `systemctl --user restart claude-usage-tray`. systemd ignores a drop-in dir that's a symlink, so `install.sh`
  creates it as a real dir and stow links only the `.conf`. Panels `qs-panel` starts get
  `QT_SCALE_FACTOR=$SCALE` (text, padding and size, on top of the monitors' 1.25; their QML sizes are logical px
  and 8-10 pt text, which looked small). After changing it: `qs -c <config> kill` for each, the next toggle restarts it.
- Not global on purpose: `QT_SCALE_FACTOR` in Hyprland's env would also grow the Caelestia bar/launcher/lock
  screen, the other Quickshell configs, OpenRGB, qt6ct, Kvantum Manager, the polkit prompt and the screen-share
  picker. (Chromium, Steam, Heroic, Thunar, kitty, VS Code are GTK/Electron and ignore it.)
- Not used by the wallpaper picker: it's fullscreen and sizes its grid from the screen height.
- A panel using compositor coordinates divides them by its scale: the claude-usage panel's `cursorY / qtScale`
  (`qtScale` = `QT_SCALE_FACTOR` from its env).

## Claude usage tray (ours)

Replaces Omarchy's Claude usage indicator. **Source of truth: `~/Dev/Personal/claude-usage-tray`**
(git, own repo `xKirtle/claude-usage-tray`, private). The installed paths below are symlinks into it
(made by its `install.sh`), so edit the repo and commit. Three pieces:
- `~/.local/bin/claude-usage-tray` (Python, dbus + cairo): tray icon + hover menu. Run by
  `claude-usage-tray.service` (user unit, `graphical-session.target`). It re-registers on its own
  when Caelestia restarts.
  - Icon: **outer ring = 5-hour limit, inner ring = weekly**. Colours: scheme primary, then peach
    (warning) and scheme error (critical), from the API's `severity`. Grey means stale.
  - Hover menu: every limit (5-hour, Weekly, Fable…) with its reset time, tokens in the current
    5-hour window, last update, Details, Refresh now. Left click = details panel; right click = refresh.
- **Limits:** `GET https://api.anthropic.com/api/oauth/usage` (undocumented; what Claude Code's
  `/usage` reads, header `anthropic-beta: oauth-2025-04-20`), using the access token in
  `~/.claude/.credentials.json`. It **never refreshes the token**, because refreshing would rotate it
  under Claude Code. While the token is expired it keeps the last result, marked stale, and picks up
  again once Claude Code renews the token. Polls every 5 min, plus on hover if the last check is >60 s old.
  The response's `limits[]` list drives the rows, so new scoped limits appear automatically.
- **Token history:** Claude Code transcripts `~/.claude/projects/**/*.jsonl` (assistant `message.usage`,
  deduped by message id + request id), rescanned every 60 s (only files modified in the current week).
  Days are 24 h slices of the weekly limit window (they start at the weekly reset time, ~05:00 local),
  not calendar days. This counts **Claude Code on this PC only**: claude.ai usage counts toward
  the limits but isn't in the history.
- `~/.config/quickshell/claude-usage/shell.qml`: details panel (separate Quickshell config, so
  Caelestia updates don't touch it). Started on first click (`qs -c claude-usage -d`, with
  `QT_SCALE_FACTOR` from the tray's `--panel-scale`, see Panel launcher above), toggled via
  `qs -c claude-usage ipc call panel toggle <monitor> <y>`. It opens next to the bar at cursor
  height; click outside or press Esc to close. It shows limit bars, a weekly per-day chart (hover a day),
  and an input / output / cache write / cache read breakdown (cache reads are ~98% of the total).
  The title shows the plan ("Claude usage (Max 5x)"), built from `subscriptionType` + `rateLimitTier`
  in the credentials file. Colours come from `~/.local/state/caelestia/scheme.json`; font is Caelestia's Google Sans Flex.
  **It doesn't live-reload:** after editing, `qs -c claude-usage kill` and click the icon again.
- Shared state: `~/.cache/claude-usage/state.json`, which also keeps the last good API response across restarts.
- Logs: `journalctl --user -u claude-usage-tray`, `qs -c claude-usage log`.

## Keybinds panel (ours)

**Super+K** toggles `~/.config/quickshell/keybinds/shell.qml` (`keybinds` package, its own Quickshell config)
through `qs-panel keybinds keybinds` (see Panel launcher above).

- Lists the live binds from `hyprctl binds -j` (re-read on every open), so defaults and ours all
  show. The text is each bind's `description` (`"Group: text"`; the group is the section). Same description +
  modifiers share a row (Super + 1 / 2 / … / 0). Binds without a description go under "Undocumented";
  undescribed pass-through binds are hidden (Caelestia adds Caps_Lock/Num_Lock ones at runtime for its
  lock-key indicator).
- Search: words match key names, descriptions and sections (`screenshot`, `super f`); with a `+` it's a
  combo (`super+shift+v`, `win+k`). Exact key matches rank first. ↑/↓/PgUp/PgDn scroll, Esc = clear, then close.
- Colours follow `scheme.json` live. Saving `shell.qml` made the running instance reload it (2026-10-26). A
  `qs -c keybinds kill` right after an edit crashed it mid-reload (harmless Quickshell crash dialog): let it reload.
- Not listed: in-app shortcuts (Thunar's F4, Caelestia's launcher keys); those stay in 02.

## Fonts

- Installed: `noto-fonts`, `noto-fonts-cjk`, `noto-fonts-emoji`, `inter-font`, `ttf-liberation`,
  plus the existing `ttf-jetbrains-mono-nerd`.
- `~/.config/fontconfig/fonts.conf`: sans = Inter, serif = Noto Serif, mono = JetBrainsMono Nerd
  Font, emoji = Noto Color Emoji; grayscale AA, slight hinting. Rebuild cache: `fc-cache -f`.

## Terminal: kitty

- `~/.config/kitty/kitty.conf`: JetBrainsMono Nerd Font 12, padding 10, opacity 0.92,
  copy-on-select, powerline tabs, beam cursor + cursor trail, 20k scrollback.
- Colours: `~/.config/kitty/catppuccin-mocha.conf` (included).
- `Ctrl+Shift+T` / `Ctrl+Shift+Enter`: new tab / window in the current directory.
- Reload running kitties: `pkill -USR1 kitty`.

## GTK / Qt theming

- GTK: theme `adw-gtk3-caelestia-a`/`-b` (below), icons `Papirus-Dark-Caelestia` / `Papirus-Light-Caelestia`
  (below), cursor `Bibata-Modern-Ice` 24, font Inter 11. Set in `~/.config/gtk-3.0/settings.ini`,
  `gtk-4.0/settings.ini` **and** gsettings (`org.gnome.desktop.interface …`); GTK apps on Wayland go by
  gsettings (via the settings portal). GUI tweaker: `nwg-look` (don't pick a theme there: the next scheme
  change sets it back).
- **GTK colours follow the wallpaper live** (2026-10-29, `themectl sync` → `gtk_theme`). Caelestia's GTK step
  is **off** (`theme.enableGtk: false` in `~/.config/caelestia/cli.json`): it wrote the colours to
  `~/.config/gtk-3.0/gtk.css`, which GTK 3 reads only at app start, so a running Thunar kept the old
  background (dark/light) until restarted; it also always set `adw-gtk3-dark`, even for light schemes.
  `gtk_theme` does its job instead: renders Caelestia's own `gtk.css` + `thunar.css` templates (from the
  installed `caelestia` package, `data/templates/`) into a **GTK theme** in `~/.local/share/themes/` that
  first `@import`s `adw-gtk3-dark` or `adw-gtk3` by the scheme's mode. GTK 3 rereads a theme whenever
  gsettings `gtk-theme` changes name, so there are two slots, `adw-gtk3-caelestia-a`/`-b`: it writes the
  inactive one and switches to it (live restyle, no restart). `adw-gtk3-caelestia` is a symlink to the
  current slot, for `settings.ini`. It also sets `color-scheme` (`prefer-dark`/`-light`) and `icon-theme`
  (`Papirus-<Mode>-Caelestia`), and removes any `~/.config/gtk-3.0/gtk.css`/`thunar.css` (user CSS would
  override the theme with stale colours). GTK 4 / libadwaita apps still get `~/.config/gtk-4.0/gtk.css` +
  `thunar.css`, read at start only. `themectl gtk` applies all of it (and the folder icons) by hand.
- **Folder icons follow the wallpaper** (2026-10-29): `themectl sync` (`papirus_folders`) generates the
  icon themes **`Papirus-Dark-Caelestia`** and **`Papirus-Light-Caelestia`** in `~/.local/share/icons/`
  (not in the repo, generated). They contain only the folder icons (`places/folder-*`, `user-*`, sizes
  22–64): Papirus's **blue** folders with its 3 colours swapped: front `#5294e2` → primary, back `#4877b1`
  → primary at ~0.78 brightness, emblem `#1d344f` → ~0.35. Everything else is inherited from
  Papirus-Dark/-Light; `gtk_theme` sets the one for the mode. It skips the rebuild if the primary didn't
  change (`.primary` stamp); `themectl gtk` forces one. Qt apps pick it up on restart (`qt6ct.conf`
  `icon_theme=Papirus-Dark-Caelestia`).
  **Live in GTK apps:** GTK only rechecks a theme's files (at most every 5 s) when the app looks up an icon,
  so an idle Thunar kept the old folders until restarted. After a rebuild, `gtk_icons_reload` sets gsettings
  `icon-theme` to `Papirus-<Mode>-Caelestia-Reload` (a symlink to the same theme, so no flicker), then 0.5 s
  later back to `Papirus-<Mode>-Caelestia` (mode from `scheme.json`). The name change makes GTK reload
  (checked headless: the IconTheme `changed` signal fires). Only if the current icon theme is one of ours.
  The `-Reload` aliases show up in theme pickers like nwg-look; ignore them.
  Why not papirus-folders: Caelestia's own recolour runs `sudo -n papirus-folders -C <nearest colour>`,
  which silently fails without passwordless sudo. The system Papirus folders are still set to
  `cat-mocha-mauve` from setup (the source of the old always-purple folders); nothing uses them now.
- Qt: `qt6ct` (`QT_QPA_PLATFORMTHEME` in `qol.lua`; `~/.config/qt6ct/qt6ct.conf`), style **Fusion**
  with `custom_palette=true` and `color_scheme_path=~/.local/state/caelestia/theme/qt6ct.conf` (qt6ct
  expands `~`). That file is rendered from our Caelestia template `templates/qt6ct.conf` (Material 3
  roles → the 21 QPalette roles in qt6ct order) on every scheme change, so Qt apps follow the wallpaper
  colours after a restart. Saving from the qt6ct GUI would write an absolute path; keep the `~`.
  Added 2026-10-28 (before: Kvantum `catppuccin-mocha-mauve`, a fixed palette).
- **Revert to Kvantum:** in `qt6ct.conf` set `style=kvantum-dark`, `custom_palette=false` (the Kvantum
  config `~/.config/Kvantum/kvantum.kvconfig` is still in place).
- Check the palette Qt apps get, headless (needs the Qt 6 `qml`; `qml` on PATH is Qt 5): a QML `Window` with
  `SystemPalette` logging `window`/`highlight`, run with `QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen
  QT_QPA_PLATFORMTHEME=qt6ct /usr/lib/qt6/bin/qml -a widget <file>`.
- Caelestia's scheme command also writes `~/.config/qtengine/` (for its own `qtengine` Qt theme),
  but this system uses `qt6ct`, so those files are unused.

## Screenshots

- Print → Caelestia region picker → **swappy** editor. Nothing is copied or saved until you press
  copy (Ctrl+C) or save (Ctrl+S) in swappy.
- `~/.config/swappy/config`: `save_dir=$HOME/Pictures/Screenshots`, name `screenshot-%Y%m%d-%H%M%S.png`.
- Caelestia also has clipboard-only actions (`caelestia:screenshotClip`, `screenshotFreezeClip`),
  currently unbound.
- **Recording:** Ctrl+Print runs `caelestia record -r`, a toggle: the first press picks a region with slurp
  and starts **gpu-screen-recorder** (NVENC, no audio; fps = the highest refresh rate of the monitors the
  region touches), the next press stops it. While recording, the file is `~/.local/state/caelestia/record/recording.mp4`;
  on stop it moves to `~/Videos/Recordings/recording_<date>.mp4` (`CAELESTIA_RECORDINGS_DIR` overrides) and a
  notification offers Watch / Open / Delete. Options: `-s` adds desktop audio, `-p` pauses/resumes,
  `-c` copies the file to the clipboard; extra recorder flags go in `record.extraArgs` in `~/.config/caelestia/cli.json`.
  gpu-screen-recorder takes slurp's logical coordinates directly (scale 1.25 is handled).

## Clipboard history

- `cliphist` fed by two `wl-paste --watch` processes started at login (text + image).
- Open with Super+Shift+V (`caelestia clipboard`, uses fuzzel).
- If history is empty after login, check `pgrep -af 'wl-paste --type'`.

## File manager: Thunar

- `thunar`, `thunar-volman`, `gvfs`, `tumbler`, `ffmpegthumbnailer`.
- Default for folders: `xdg-mime default thunar.desktop inode/directory`.
- Themed by Caelestia's `thunar.css` template, via our generated GTK theme (live; see GTK / Qt theming). Dolphin was removed because it looked bad with the theme.
- **Archives: no archive manager app.** Right-click **Extract here** / **Extract to folder** / **Compress to .zip**
  are our Thunar actions running `~/.local/bin/archive-tool` (`thunar` package) with `bsdtar` (libarchive)
  and `7zip` as the fallback. Extract here: a single top-level item lands next to the archive; anything else
  goes into a folder named after it. Never overwrites (clashes get " (2)"…), extracts via a hidden
  `.extracting-*` dir on the same filesystem, and refuses `..`/absolute paths. Password-protected archives
  aren't supported (it says so instead of prompting). Compress zips the selection into `<name>.zip`
  (several items: `<folder>.zip`). A notification reports each result.
  Replaced File Roller + `thunar-archive-plugin`, whose drag-out didn't work on Wayland (X11-only XDS).
- **Browse archive** (double-click or right-click an archive; ours): opens it as a folder in Thunar so files
  can be **dragged out** like from any folder. Two FUSE layers (both just `fuse3` + `libarchive`):
  **`fuse-archive`** (AUR) mounts the archive read-only in `$XDG_RUNTIME_DIR/archives/.lower/<id>`, and
  **`fuse-overlayfs`** puts a throwaway writable layer on top (`~/.cache/archive-mount/layers/<id>`), mounted
  at `$XDG_RUNTIME_DIR/archives/"<name> (archive <id>)"`. Why the overlay: Thunar on Wayland treats a
  drag-out as a **move** (copy, then delete the source), and on the read-only mount alone the delete failed
  with "Error removing file … Read-only file system" (read-only permission masks didn't change that). With
  the overlay the delete only hides the file in the browsed view; **the archive itself is never modified**.
  **Close archive** (right-click the folder or its background) does *lazy* unmounts of both layers and deletes
  the writable layer; lazy because the Thunar window showing the archive keeps it busy, so a normal unmount
  from its own menu always failed ("still in use"). Everything also goes at logout.
  Script: `~/.local/bin/archive-mount open|close|list` (`thunar` package; `-o lazycache`, cache on disk).
  Ark (KDE) would also do drag-out but pulls ~40 KDE packages.
  - **Double-click** opens archives this way: `~/.local/share/applications/archive-browse.desktop`
    (`thunar` package, hidden from launchers) is the default for zip, 7z, rar, tar.*, iso, cab and cpio
    (`xdg-mime default archive-browse.desktop <types>`; the list is its `MimeType=` line; backup
    `~/.config/mimeapps.list.bak-pre-archive-browse`).
    `~/.local/share/applications` must exist before stowing (install.sh creates it) so stow links the
    single file instead of folding the whole folder into the repo.
- **Open Terminal Here** (right-click, or **F4**): custom action in `~/.config/Thunar/uca.xml`, changed to
  run `kitty --directory` directly (the stock `exo-open … TerminalEmulator` had no preferred terminal set).
  The F4 bind is in `accels.scm` as `<Actions>/ThunarActions/uca-action-1792778832572115-1`.
  **Quit Thunar (`thunar -q`) before editing `accels.scm`**, because it overwrites the file with its in-memory copy.
  Stock copies: `uca.xml.orig`, `accels.scm.orig`.
