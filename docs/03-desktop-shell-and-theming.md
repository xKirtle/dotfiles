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
- **Config:** `~/.config/caelestia/shell.json`. **Only read at startup**; restart the shell after editing.
  It's **generated**: edit `shell.json.template` (tracked) and re-render with `./install.sh caelestia`
  from the repo; private values (`${WEATHER_LOCATION}`) come from the repo's gitignored `.env`
  (README: "Private values"). `shell.json` itself is gitignored, and anything written straight into it
  (by hand or Caelestia's settings app) is lost on the next render, so copy such changes into the template.
  Full option reference: README of <https://github.com/caelestia-dots/shell>. Current contents:
  - `bar.statusIcons`: lockStatus, **microphone**, **kbLayout**, network, bluetooth, battery enabled; audio off.
    It's an array, so list all entries, not just the changed ones.
  - `osd.enableMicrophone: true`: popup on mic volume/mute changes.
  - `bar.clock.showDate: true`: date next to the bar clock.
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
- **Colour scheme:** normally via the themectl theme picker (below); by hand:
  `caelestia scheme set -n catppuccin -f mocha -m dark`, or `-n dynamic` for wallpaper-based colours.
  - **How it works:** `caelestia-cli` (Python). Named schemes are fixed palettes shipped with it.
    `dynamic` takes a seed colour from the wallpaper thumbnail with `python-materialyoucolor` (Google's
    Material Color Utilities, the same algorithm as matugen) and builds a Material 3 palette plus 16
    terminal colours (`variant` = tonalspot/vibrant/…). Result: `~/.local/state/caelestia/scheme.json`.
  - **What follows it:** Caelestia's shell and our Quickshell panels (live, from `scheme.json`); template
    files for GTK 3/4 (`gtk.css`), `thunar.css`, btop, htop, nvtop, fuzzel, cava, Discord, Spicetify,
    Zed, Warp; **running terminals** (it writes OSC colour sequences to every `/dev/pts/*`);
    **new terminals** (our `~/.bashrc` runs `command cat ~/.local/state/caelestia/sequences.txt`; `command`
    because `cat` is aliased to `bat`, which adds a "File:" header; backup
    `.bashrc.bak-pre-sequences`); **Hyprland borders**, **Chromium** and **Serein** (via `themectl sync`, see below;
    Serein only after a restart); **Spotifast** (live, see next point).
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
  - **What doesn't:** Qt apps stay on Kvantum Catppuccin (Caelestia targets `qtengine`, unused here;
    OpenRGB is the only Qt app, so it's not worth switching to Fusion). kitty's own
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
- Logs of the running instance: `/run/user/1000/quickshell/by-id/*/log.qslog` (binary-ish; use `strings`).
- Test-run in the foreground to see errors: `timeout 8 qs -c caelestia -n`.
- **Keep awake** (idle inhibitor): **Super+Shift+I** toggles it and notifies the new state; CLI
  `caelestia shell idleInhibitor toggle|enable|disable|isEnabled`. Only on-screen indicator: the
  "Keep awake" card in the utilities drawer ("Preventing sleep mode", "Active since …"); no bar icon.
- **No plugin system yet** (2.5.0): Nexus has a "Plugins" entry, but `AboutPage.qml` says it isn't
  wired up. Bar entries are a fixed list (logo, workspaces, activeWindow, tray, clock, statusIcons,
  power), so custom bar widgets go through the **tray** (any StatusNotifierItem shows there; hovering
  opens its D-Bus menu as a popout; there are no tooltips). A copy in `~/.config/quickshell/caelestia`
  would override the packaged shell, but that's a fork that stops getting pacman updates.

## Themes and wallpapers (ours, Omarchy-style)

A **theme** is a folder in `~/Pictures/Wallpapers/<theme>/` plus a Caelestia colour scheme.
- **Scheme from the folder name:** `<scheme>` or `<scheme>-<flavour>` (`catppuccin-mocha`,
  `gruvbox-hard`, `rosepine-moon`…; flavour defaults to the scheme's first, e.g. everforest → soft).
  An optional `scheme` file in the folder overrides it: `"<scheme> [flavour] [dark|light]"`, e.g.
  `catppuccin latte light` or `dynamic`. Any other folder name (e.g. `scenic`) = **dynamic** (colours from
  the wallpaper). Loose images in the root form a pseudo-theme `unsorted` (dynamic).
- **Current folders:** catppuccin-mocha (3), dracula (2), nord (2), scenic (3), tokyonight, gruvbox-hard,
  everforest, darkgreen (1 each). `catppuccin-mocha/3840x2160.png` is really **1000×563**, so it's
  blurry at 4K, and it sorts first, so it's what picking that theme shows.
- **Pickers** (`~/.config/quickshell/theme-picker/shell.qml`, its own Quickshell config, a full-screen
  overlay on the focused monitor):
  - **Super+Ctrl+Shift+Space: themes.** Shows a preview with a wallpaper-count badge, the scheme
    name and colour swatches.
    **Enter (or click) = choose the wallpaper**: shows that theme's wallpapers, where Enter applies
    theme + wallpaper and Esc/Backspace goes back. One-wallpaper themes apply directly.
    **Shift+Enter (or Shift+click / right-click) = apply with its first wallpaper.**
    (A random-wallpaper option and a Tab binding were tried and dropped.)
  - **Super+Ctrl+Space: wallpapers** of the current theme.
  - Arrows/hjkl move, Esc or a click outside closes. Colours follow `scheme.json`.
  - It doesn't live-reload: `qs -c theme-picker kill` after editing (the next bind press restarts it).
  - It calls `~/.local/bin/themectl` by **absolute path**: the session PATH (Hyprland/uwsm) lacks
    `~/.local/bin`, so a bare `themectl` fails ("Process failed to start" in `qs -c theme-picker log`).
- **`~/.local/bin/themectl`** (Python): `list [--json]`, `set <theme> [file]`, `current`,
  `picker themes|wallpapers`, `sync`. State: `~/.local/state/themectl/current.json`.
  `THEMECTL_WALLPAPERS=<dir>` points it at another folder (handy for testing).
  `set` runs `caelestia scheme set …`, then `caelestia wallpaper -f <file> -N` (`-N` = don't
  auto-switch light/dark). For dynamic themes it sets the wallpaper first, then the `dynamic` scheme.
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
  It also writes a **Serein** theme (`serein_theme`, see "Discord client: Serein" below).
  Caelestia writes `scheme.json` **atomically** (temp file + `os.replace`), which arrives as a
  RENAMED event whose *destination* is the watched file; the watcher matches both ends. To test,
  rewrite it the same way (a plain `cat >` only exercises the in-place path).
  The service's memory peak is ~470 MB, from `awww img` decoding the 5K/6K PNGs; it's short-lived.
  Check: `awww query`; logs: `journalctl --user -u themectl-sync`.

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
  Caelestia updates don't touch it). Started on first click (`qs -c claude-usage -d`), toggled via
  `qs -c claude-usage ipc call panel toggle <monitor> <y>`. It opens next to the bar at cursor
  height; click outside or press Esc to close. It shows limit bars, a weekly per-day chart (hover a day),
  and an input / output / cache write / cache read breakdown (cache reads are ~98% of the total).
  The title shows the plan ("Claude usage (Max 5x)"), built from `subscriptionType` + `rateLimitTier`
  in the credentials file. Colours come from `~/.local/state/caelestia/scheme.json`; font is Caelestia's Google Sans Flex.
  **It doesn't live-reload:** after editing, `qs -c claude-usage kill` and click the icon again.
- Shared state: `~/.cache/claude-usage/state.json`, which also keeps the last good API response across restarts.
- Logs: `journalctl --user -u claude-usage-tray`, `qs -c claude-usage log`.

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

- GTK: `adw-gtk3-dark`, icons `Papirus-Dark` (folders recoloured with
  `papirus-folders -C cat-mocha-mauve`), cursor `Bibata-Modern-Ice` 24, font Inter 11.
  Set in `~/.config/gtk-3.0/settings.ini`, `gtk-4.0/settings.ini` **and** gsettings
  (`org.gnome.desktop.interface …`, color-scheme `prefer-dark`). GUI tweaker: `nwg-look`.
- Qt: `qt6ct` (`~/.config/qt6ct/qt6ct.conf`, style `kvantum-dark`) + Kvantum theme
  `catppuccin-mocha-mauve` (`~/.config/Kvantum/kvantum.kvconfig`).
- Caelestia's scheme command also writes `~/.config/qtengine/` (for its own `qtengine` Qt theme),
  but this system uses `qt6ct` (`QT_QPA_PLATFORMTHEME` in `qol.lua`), so those files are unused.

## Screenshots

- Print → Caelestia region picker → **swappy** editor. Nothing is copied or saved until you press
  copy (Ctrl+C) or save (Ctrl+S) in swappy.
- `~/.config/swappy/config`: `save_dir=$HOME/Pictures/Screenshots`, name `screenshot-%Y%m%d-%H%M%S.png`.
- Caelestia also has clipboard-only actions (`caelestia:screenshotClip`, `screenshotFreezeClip`),
  currently unbound.

## Clipboard history

- `cliphist` fed by two `wl-paste --watch` processes started at login (text + image).
- Open with Super+Shift+V (`caelestia clipboard`, uses fuzzel).
- If history is empty after login, check `pgrep -af 'wl-paste --type'`.

## File manager: Thunar

- `thunar`, `thunar-archive-plugin`, `thunar-volman`, `gvfs`, `tumbler`, `ffmpegthumbnailer`.
- Default for folders: `xdg-mime default thunar.desktop inode/directory`.
- Themed by Caelestia's `gtk-3.0/thunar.css`. Dolphin was removed because it looked bad with the theme.
- Archives: `file-roller` + `7zip`.
- **Open Terminal Here** (right-click, or **F4**): custom action in `~/.config/Thunar/uca.xml`, changed to
  run `kitty --directory` directly (the stock `exo-open … TerminalEmulator` had no preferred terminal set).
  The F4 bind is in `accels.scm` as `<Actions>/ThunarActions/uca-action-1792778832572115-1`.
  **Quit Thunar (`thunar -q`) before editing `accels.scm`**, because it overwrites the file with its in-memory copy.
  Stock copies: `uca.xml.orig`, `accels.scm.orig`.
