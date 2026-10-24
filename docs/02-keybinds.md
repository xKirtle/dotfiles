# Keybinds

Custom binds live in `~/.config/hypr/qol.lua`; defaults in `hyprland.lua`; a few in HyprMod's
`hyprland-gui.lua`. "Super" = Windows key.

## Apps and shell

| Key | Action | Defined in |
|---|---|---|
| Super + Return | kitty | HyprMod |
| Super + Space | Caelestia launcher (type `>` for commands, e.g. `>scheme`, `>wallpaper`) | qol |
| Super + E | Thunar | qol |
| Super + B | Chromium | HyprMod |
| Super + Q | close window | HyprMod |
| Super + Shift + Q | kill window | HyprMod |
| Super + L | lock screen | qol |
| Super + Esc | power / session menu (log out lives here) | qol |
| Super + N | notifications sidebar | qol |
| Super + Shift + N | clear notifications | qol |
| Super + D | show all panels | qol |
| Ctrl + Super + Alt + R | restart Caelestia shell | qol |
| Super + Shift + I | keep awake on/off (Caelestia idle inhibitor: no auto-lock or screen off; notifies the new state) | qol |
| Super + Ctrl + Shift + Space | theme picker (Enter = choose wallpaper, Shift+Enter = apply with first wallpaper) | qol |
| Super + Ctrl + Space | wallpaper picker (current theme) | qol |
| Super + A | agenda panel: Proton Calendar, today + next 4 days (←/→ = previous/next 5 days, T = today, ↑/↓ = select event, Enter/click = details (click links, drag to select, Ctrl+C copies), O = open its first link, R = sync now, Esc = close; see 08) | qol |

## Screenshots, clipboard, pickers

| Key | Action |
|---|---|
| Print | select region → opens in **swappy** (Ctrl+C copy, Ctrl+S save) |
| Shift + Print | full-screen screenshot |
| Super + Print | freeze screen, then select region |
| Super + Shift + V | clipboard history |
| Super + . | emoji picker |
| Super + Shift + C | colour picker (copies hex) |

swappy saves to `~/Pictures/Screenshots` (`~/.config/swappy/config`).

## Windows: scrolling tape

Arrow keys are **rotated 90° on the portrait monitor (workspaces 6–10)** so they follow the tape.

| Action | Landscape (1–5) | Portrait (6–10) |
|---|---|---|
| Move column back / forward | Super + Left / Right | Super + Up / Down |
| Maximize toggle | Super + Up | Super + Right |
| *(free)* | Super + Down | Super + Left |
| Shrink / grow column | Super + Shift + Left / Right | Super + Shift + Up / Down |
| Take window out of scratchpad | Super + Shift + Up | Super + Shift + Right |
| Send window to scratchpad | Super + Shift + Down | Super + Shift + Left |

A window *inside* the scratchpad uses the layout of the monitor the scratchpad is open on.
To change any of these, edit the `tape_binds` table in `qol.lua` (one row per key:
landscape action, portrait action).

| Key | Action |
|---|---|
| Super + scroll / Super + Tab | focus next column (follows tape direction) |
| Super + Shift + Tab / scroll up | focus previous column |
| (at tape ends) | Tab / Shift+Tab (and Super+scroll) stay on the current workspace: at the first or last column they do nothing. Plain `focus` would hop monitors off the first column (portrait is left of main) or bounce back a column off the last one |
| Super + Shift + scroll | previous / next workspace |
| Super + [ / Super + ] | stack window into previous / next column, or pop it back out |
| Super + F | fullscreen |
| Super + Shift + F, Super + M | maximize |
| Super + V | toggle floating |
| Super + mouse left / right drag | move / resize window |

## Workspaces and scratchpad

| Key | Action |
|---|---|
| Super + 1–5 | workspaces on the main monitor |
| Super + 6–9, 0 | workspaces on the portrait monitor (0 = 10) |
| Super + Shift + digit | send window to that workspace |
| Super + S | show / hide the scratchpad (`special:magic`) |
| Super + Shift + S | **unbound** (was a toggle; use the arrow keys above) |

## Audio

| Key | Action |
|---|---|
| Super + ` | toggle output: Scarlett headphones ↔ S/PDIF speakers |
| Volume keys | output volume / mute |
| Super + Mute | mute / unmute **microphone** |
| Super + Volume Up / Down | mic level ±5% (max 100%) |
| Play/Pause/Next/Prev | media via Caelestia (OSD) |

## Keyboard

| Key | Action |
|---|---|
| Left Alt + Left Shift | switch layout US ↔ PT (shown in the bar) |

## In-app (not Hyprland)

| Key | Where | Action | Set in |
|---|---|---|---|
| F4 | Thunar | open kitty in the current folder (or the selected file's folder) | `~/.config/Thunar/accels.scm` |
