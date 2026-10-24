# dotfiles

Arch + Hyprland (Lua config, uwsm) + [Caelestia](https://github.com/caelestia-dots/shell) shell,
themed Catppuccin Mocha by default, with Omarchy-style theme switching. The detailed notes on how
everything is set up, and why, are in [`docs/`](docs/README.md); start there.

## Layout

Each top-level folder is a [GNU Stow](https://www.gnu.org/software/stow/) package mirroring `$HOME`:

| Package | What |
|---|---|
| `hypr` | Hyprland: `hyprland.lua` (input), `hyprland-gui.lua` (**HyprMod-managed; don't hand-edit**), `qol.lua` (everything else) |
| `caelestia` | Caelestia shell config (`shell.json.template`, rendered to `shell.json`) |
| `themectl` | Theme + wallpaper pickers, awww transitions, scheme sync (`themectl`, Quickshell picker, user units) |
| `kitty`, `shell`, `bash` | Terminal, starship prompt, bash |
| `gtk`, `qt`, `fonts` | GTK 3/4 settings, qt6ct + Kvantum, fontconfig |
| `thunar`, `swappy`, `chromium` | Thunar actions + shortcuts, screenshot editor, Chromium flags |
| `audio` | WirePlumber rules (Scarlett Solo) + output switch script |
| `paru` | paru config + AUR completion refresh timer |
| `calendar` | Proton Calendar: vdirsyncer + khal configs, `calendarctl` (sync, reminders), agenda panel, user units |
| `system` | Reference copies of `/etc` files, installed by hand ([system/README.md](system/README.md)) |
| `docs` | The setup notes |

Separate repo: [claude-usage-tray](https://github.com/xKirtle/claude-usage-tray) (tray icon for Claude usage).

## Install

```bash
sudo pacman -S stow
./install.sh            # all packages; or: ./install.sh hypr kitty
```

`.env` must exist first (`cp .env.example .env`, then fill it in; see below).
Stow refuses to overwrite real files, so move existing configs aside first.
Most app config dirs are linked **as whole folders** (e.g. `~/.config/hypr → dotfiles/hypr/.config/hypr`),
because several apps (Thunar, qt6ct, nwg-look, HyprMod) save by replacing the file, which would cut
a single-file symlink loose from the repo. Files those apps generate inside the folders are in `.gitignore`.

## Private values (`.env`)

The repo is public, so values like the weather town or calendar links live in a gitignored
**`.env`** at the repo root (`KEY=value` per line; `.env.example` lists the keys with placeholders).
Configs that can't read environment variables are tracked as `<file>.template` with `${VAR}`
placeholders. `install.sh` renders each `*.template` in the packages it installs to `<file>` (next to
it, gitignored) with `envsubst`, replacing only the variables defined in `.env` so other `$` text stays
as is, and stops with an error if `.env` is missing. After changing `.env` or a template, re-run
`./install.sh <pkg>` and restart the app. Edit the template, not the rendered file: the next render
overwrites it.

Not in here: the wallpapers (`~/Pictures/Wallpapers/<theme>/`, see docs), app state, and anything
with credentials.
