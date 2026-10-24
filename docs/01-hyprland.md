# Hyprland

## File layout (`~/.config/hypr/`)

| File | Owner | Purpose |
|---|---|---|
| `hyprland.lua` | you (auto-generated base) | Default config. Edited lines: `fileManager = "thunar"`, keyboard layouts, mouse sensitivity/accel. Ends with `require("hyprland-gui")` then `require("qol")`. |
| `hyprland-gui.lua` | **HyprMod** | Monitor modes/positions/rotation, layout = scrolling, a few binds. Rewritten whenever you save in HyprMod. Don't hand-edit. |
| `qol.lua` | setup session | Everything else: env vars, autostart, theme, binds, workspaces, window rules. Loaded last, so it wins. |
| `hyprland.lua.bak` | backup | Original before any edits |

## Input (in `hyprland.lua`, `input` section)

- `kb_layout = "us,pt"`, `kb_options = "grp:lalt_lshift_toggle"`: **Left Alt + Left Shift** switches US ↔ PT.
- `sensitivity = -0.35` with `accel_profile = "flat"` (no mouse acceleration).
  Try values live: `hyprctl eval 'hl.config({ input = { sensitivity = -0.4 } })'`.
- Ignore the `epic-mouse-v1` device block further down; it's the default example and matches nothing.

## Monitors

- Modes, positions, scale (1.25), rotation: set in **HyprMod** (`hyprland-gui.lua`), by connector name (`DP-5`, `DP-6`).
- Everything in `qol.lua` refers to monitors **by description** so it survives connector renames:
  ```lua
  local MAIN_DESC = "LG Electronics LG ULTRAGEAR+ 411NTTQ06481" -- landscape, 240Hz
  local SIDE_DESC = "LG Electronics LG ULTRAGEAR+ 402NTJJB7972" -- portrait, 144Hz
  ```
  `connector_of(desc)` looks up the current connector name for tools that need it (xrandr).
- See descriptions: `hyprctl monitors` (the `description:` line, without the trailing `(DP-x)`).
- **If a connector name ever changes** (driver update, cable moved), only HyprMod's layout breaks. Fix it in HyprMod.

## Workspaces

- **1–5 on the main monitor, 6–10 on the portrait monitor**, always present (`persistent`).
  The main monitor starts on 1 and the portrait one on 6.
- Workspaces **6–10 scroll top-to-bottom** (`layout_opts = { direction = "down" }`). The arrow
  keybinds rotate to match (see 02-keybinds.md).
- Defined in the `WORKSPACES` section of `qol.lua` (loop over 1–10).

## Layout: scrolling

- `general.layout = "scrolling"` is set by HyprMod.
- `scrolling.wrap_swapcol = false`: moving a column past either end doesn't wrap around.
- `fullscreen_on_one_column` is left at its default (on): a lone column fills the screen, so
  resizing a single window on a workspace has no visible effect.
- Useful layout messages: `swapcol l|r`, `colresize ±0.05`, `colresize +conf`,
  `consume_or_expel prev|next`, `promote`, `fit active`. Docs: <https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/>

## Environment variables (`qol.lua`)

| Variable | Why |
|---|---|
| `LIBVA_DRIVER_NAME=nvidia`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`, `NVD_BACKEND=direct` | NVIDIA video decode / GL on Wayland |
| `GDK_BACKEND`, `QT_QPA_PLATFORM`, `SDL_VIDEODRIVER`, `ELECTRON_OZONE_PLATFORM_HINT` | Prefer Wayland, fall back to X11 |
| `QT_QPA_PLATFORMTHEME=qt6ct`, `QT_WAYLAND_DISABLE_WINDOWDECORATION=1` | Qt theming via qt6ct + Kvantum |
| `XCURSOR_THEME=Bibata-Modern-Ice`, `XCURSOR_SIZE=24`, `HYPRCURSOR_SIZE=24` | Cursor |
| `STEAM_FORCE_DESKTOPUI_SCALING=1.25` | Steam UI scale (see 06-gaming-and-steam.md) |

Env vars apply to apps launched **after** login/reload, from the launcher or keybinds. Terminals
opened earlier keep their old environment.

## Autostart (`hl.on("hyprland.start", …)` in `qol.lua`)

Runs **once per login**, not on `hyprctl reload`:
1. `wl-paste … --watch cliphist store` (text + images): clipboard history
2. `hyprctl setcursor Bibata-Modern-Ice 24`
3. Focus the main monitor (`hl.dsp.focus({ monitor = MAIN })`)
4. `xrandr --output <main connector> --primary`: X11/Proton games default to the main monitor
5. `trash-empty 30`: purge trash older than 30 days
6. `caelestia shell -d`: bar, launcher, notifications, lock, wallpaper

Other autostart comes from systemd user units and `~/.config/autostart/` (see 04-login-and-session.md).

## Look and feel (`qol.lua`)

- Borders: Catppuccin Mocha, mauve→blue gradient active, surface1 inactive.
- `xwayland.force_zero_scaling = true`: X11 apps render at native resolution instead of being
  upscaled (blurry) to 1.25. They'd look ~20% smaller unless they scale themselves (Steam does,
  via the env var above).
- `misc.disable_hyprland_logo = true`, `force_default_wallpaper = 0` (Caelestia draws the wallpaper).

## Window rules (`qol.lua`, bottom)

| Rule | Effect |
|---|---|
| `float-dialogs` | pavucontrol, nm-connection-editor, nwg-look, qt6ct, kvantummanager: floating, centred, 60%×70% |
| `imv-float` | image viewer floats, centred |
| `steam-friends-narrow` | Steam "Friends List" tiles as a narrow column: `scrolling_width = 0.15` |
| `fullscreen-no-idle` | any window (`class = ".*"`): `idle_inhibit = "fullscreen"` |
| `steam-games-no-idle` | `^steam_app_.*$`: `idle_inhibit = "focus"`. Must come **after** the catch-all: the last matching rule's `idle_inhibit` wins |

Rules apply when a window **opens**; reopen it to see a change.
Check idle inhibit with `hyprctl clients -j | jq '.[] | {class, inhibitingIdle}'`.

## Lua API notes (for writing new binds)

- `hl.get_active_window()` → window object: `.class`, `.workspace.id`, `.workspace.name`,
  `.workspace.special` (true in scratchpad), `.monitor.name`, `.monitor.description`.
- `hl.get_monitors()` → list with `.name`, `.description`, `.id`.
- A bind can take a Lua function: `hl.bind(key, function() … hl.dispatch(hl.dsp.…) end, flags)`.
- Flags: `{ repeating = true }`, `{ locked = true }` (works on lock screen), `{ release = true }`, `{ mouse = true }`.
- Override a default bind: `hl.unbind("SUPER + X")` then `hl.bind(...)`.
- List live binds: `hyprctl binds -j`. Modmask 64 = Super, 65 = Super+Shift.
