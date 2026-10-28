-- QoL additions: Caelestia shell, NVIDIA env, theming, extra binds.
-- Loaded last from hyprland.lua so it can override defaults / HyprMod binds.

local mainMod = "SUPER"

-- Monitors by description (make/model/serial) so rules survive connector renames
-- (driver updates, swapped ports). Both are the same LG model; the serial tells them apart.
local MAIN_DESC = "LG Electronics LG ULTRAGEAR+ 411NTTQ06481" -- landscape, 240Hz
local SIDE_DESC = "LG Electronics LG ULTRAGEAR+ 402NTJJB7972" -- portrait, 144Hz
local MAIN = "desc:" .. MAIN_DESC
local SIDE = "desc:" .. SIDE_DESC

-- Current connector name (e.g. "DP-6") for tools that don't understand desc:, like xrandr
local function connector_of(desc)
    for _, m in ipairs(hl.get_monitors()) do
        if m.description == desc then
            return m.name
        end
    end
end

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- NVIDIA (RTX 4090) on Wayland
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")

-- Toolkit backends
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland,x11")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Theming
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- XWayland apps render at native resolution (see force_zero_scaling below),
-- so Steam scales its own UI to match the 1.25 monitor scale
hl.env("STEAM_FORCE_DESKTOPUI_SCALING", "1.25")


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    -- Clipboard history (used by `caelestia clipboard`)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")

    -- Start focus (cursor, new windows) on the main monitor
    hl.dispatch(hl.dsp.focus({ monitor = MAIN }))

    -- X11/Proton games use the primary output; otherwise they pick the portrait monitor
    local main = connector_of(MAIN_DESC)
    if main then
        hl.exec_cmd("xrandr --output " .. main .. " --primary")
    end
    hl.exec_cmd("trash-empty 30")

    -- Bar, launcher, notifications, lock screen, wallpaper
    hl.exec_cmd("caelestia shell -d")
end)


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Borders follow the Caelestia scheme (primary -> tertiary gradient). `caelestia scheme set` writes
-- scheme/current.lua; `themectl sync` re-applies these live via hyprctl eval when the scheme changes
-- (keep the two in step). Falls back to Catppuccin Mocha (mauve -> blue).
local scheme_ok, scheme = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/scheme/current.lua")
if not scheme_ok or type(scheme) ~= "table" then scheme = {} end
local function rgba(key, alpha, fallback)
    return "rgba(" .. (scheme[key] or fallback):lower() .. alpha .. ")"
end
hl.config({
    general = {
        col = {
            active_border   = { colors = {rgba("primary", "ee", "cba6f7"), rgba("tertiary", "ee", "89b4fa")}, angle = 45 },
            inactive_border = rgba("outlineVariant", "aa", "45475a"),
        },
    },
    -- Don't upscale X11 apps at fractional scale (blurry); they render natively instead
    xwayland = {
        force_zero_scaling = true,
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        -- Let a restarted shell take over a crashed lock screen (see the Super+Ctrl+Shift+L bind)
        allow_session_lock_restore = true,
    },
})


---------------------
---- KEYBINDINGS ----
---------------------

-- Apps and window basics (were HyprMod's; defaults Super+Q = terminal, C = close, R = launcher replaced)
hl.unbind(mainMod .. " + Q")
hl.unbind(mainMod .. " + C")
hl.unbind(mainMod .. " + R")
hl.bind(mainMod .. " + Return",      hl.dsp.exec_cmd("kitty"),     { description = "Apps: kitty" })
hl.bind(mainMod .. " + B",           hl.dsp.exec_cmd("chromium"),  { description = "Apps: Chromium" })
hl.bind(mainMod .. " + Q",           hl.dsp.window.close(),        { description = "Windows: close" })
hl.bind(mainMod .. " + SHIFT + Q",   hl.dsp.window.kill(),         { description = "Windows: kill" })

-- Caelestia launcher replaces hyprlauncher
hl.unbind(mainMod .. " + space")
hl.bind(mainMod .. " + space", hl.dsp.global("caelestia:launcher"), { description = "Shell: Caelestia launcher (type > for commands, e.g. >scheme)" })

hl.bind(mainMod .. " + L",           hl.dsp.global("caelestia:lock"), { description = "Shell: lock screen" })
hl.bind(mainMod .. " + Escape",      hl.dsp.global("caelestia:session"), { description = "Shell: power / session menu (log out lives here)" })
hl.bind(mainMod .. " + N",           hl.dsp.global("caelestia:sidebar"), { description = "Shell: notifications sidebar" })
hl.bind(mainMod .. " + SHIFT + N",   hl.dsp.global("caelestia:clearNotifs"), { description = "Shell: clear notifications" })
hl.bind(mainMod .. " + D",           hl.dsp.global("caelestia:showall"), { description = "Shell: show all panels" })

-- Keep awake: toggle Caelestia's idle inhibitor (no auto-lock / screen off), with a notification
-- saying the new state (the only other indicator is the "Keep awake" card in the utilities drawer)
hl.bind(mainMod .. " + SHIFT + I", hl.dsp.exec_cmd([[caelestia shell idleInhibitor toggle; if [ "$(caelestia shell idleInhibitor isEnabled)" = true ]; then notify-send -a caelestia-shell -i caffeine-cup-full "Keep awake: on" "The screen won't lock or turn off"; else notify-send -a caelestia-shell -i caffeine-cup-empty "Keep awake: off" "Auto-lock is back on"; fi]]), { description = "Shell: keep awake on / off (no auto-lock or screen off)" })

-- Away mode: monitors off without locking; agents keep working on a virtual monitor
-- (`awayctl`, docs 01). Same size/scale as the main monitor, far off to the side so the
-- cursor can't wander onto it. Kept here so a `hyprctl reload` doesn't reset it.
hl.monitor({ output = "agent", mode = "3840x2160@60", position = "20000x0", scale = 1.25 })
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/awayctl toggle"), { description = "Shell: away mode on / off (monitors off, no lock; agents use a virtual monitor)" })

-- Restart the shell if it ever dies
-- (wait for the old instance to fully exit, or the new one quits seeing it still running)
-- (match only Caelestia's qs, other Quickshell configs run too; '^' keeps it off this sh's own command line)
hl.bind("CTRL + " .. mainMod .. " + ALT + R", hl.dsp.exec_cmd("qs -c caelestia kill; for i in $(seq 50); do pgrep -f '^qs -c caelestia' >/dev/null || break; sleep 0.1; done; caelestia shell -d"), { release = true, description = "Shell: restart the Caelestia shell" })

-- Recover a crashed lock screen ("lockscreen crashed" red screen; Caelestia's lock dies when the
-- monitors drop off while locked): restart the shell, wait until its IPC answers, then lock again
hl.bind("CTRL + " .. mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("qs -c caelestia kill; for i in $(seq 50); do pgrep -f '^qs -c caelestia' >/dev/null || break; sleep 0.1; done; caelestia shell -d; for i in $(seq 100); do [ \"$(caelestia shell lock isLocked 2>/dev/null)\" = false ] && break; sleep 0.2; done; caelestia shell lock lock"), { locked = true, release = true, description = "Shell: recover a crashed lock screen (restart the shell, lock again)" })

-- Screenshots: Print = region, Shift+Print = full screen, Super+Shift+S-style freeze
hl.bind("Print",                     hl.dsp.global("caelestia:screenshot"), { description = "Screenshots: select a region, then edit in swappy (Ctrl+C copy, Ctrl+S save)" })
hl.bind("SHIFT + Print",             hl.dsp.exec_cmd("caelestia screenshot"), { description = "Screenshots: full screen" })
hl.bind(mainMod .. " + Print",       hl.dsp.global("caelestia:screenshotFreeze"), { description = "Screenshots: freeze the screen, then select a region" })
-- Ctrl+Print = record a region (gpu-screen-recorder via Caelestia); press again to stop
hl.bind("CTRL + Print",              hl.dsp.exec_cmd("caelestia record -r"), { description = "Screenshots: record a region (press again to stop)" })

-- Clipboard history / emoji picker / color picker
hl.bind(mainMod .. " + SHIFT + V",   hl.dsp.exec_cmd("pkill fuzzel || caelestia clipboard"), { description = "Clipboard: clipboard history" })
hl.bind(mainMod .. " + period",      hl.dsp.exec_cmd("pkill fuzzel || caelestia emoji -p"), { description = "Clipboard: emoji picker" })
hl.bind(mainMod .. " + SHIFT + C",   hl.dsp.exec_cmd("hyprpicker -a"), { description = "Clipboard: colour picker (copies the hex)" })

-- Toggle audio output: Scarlett headphones <-> S/PDIF speakers
hl.bind(mainMod .. " + grave",       hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/cycle-audio-output.sh"), { description = "Audio: toggle output, Scarlett headphones / S/PDIF speakers" })

-- Dictation: F9 starts / stops recording, then whisper.cpp types the text (dictate package)
hl.bind("F9",                        hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/dictate"), { description = "Audio: dictation start / stop (types the text into the focused window)" })
hl.bind("SHIFT + F9",                hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/dictate cancel"), { description = "Audio: cancel dictation" })

-- Wallpaper picker: every wallpaper gets its own dynamic colours; folders are only groups
hl.bind("CTRL + " .. mainMod .. " + space", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/themectl picker"), { description = "Panels: wallpaper picker (each wallpaper sets its own colours)" })

-- Agenda panel: Proton Calendar, today + next days (calendar package, qs -c agenda)
hl.bind(mainMod .. " + A",           hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/calendarctl panel"), { description = "Panels: agenda (Proton Calendar)" })

-- VPN panel: Proton VPN country/city/server picker (vpn package, qs -c vpn). Shift so it's hard to hit by accident
hl.bind(mainMod .. " + SHIFT + P",   hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/vpnctl panel"), { description = "Panels: VPN (Proton VPN country / city / server picker)" })

-- Keybind cheat sheet: searchable list of the live binds and their descriptions (keybinds package, qs -c keybinds)
hl.bind(mainMod .. " + K",           hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/qs-panel keybinds keybinds"), { description = "Panels: keybinds (this cheat sheet)" })

-- System monitor: graphs + task manager (sysmon package, qs -c sysmon). Windows' Task Manager shortcut
hl.bind("CTRL + SHIFT + Escape",     hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/sysmonctl panel"), { description = "Panels: system monitor (graphs, task manager: filter, end / force kill)" })

-- Thunar picks up Caelestia's GTK theme (replaces dolphin)
hl.unbind(mainMod .. " + E")
hl.bind(mainMod .. " + E",           hl.dsp.exec_cmd("thunar"), { description = "Apps: Thunar" })

-- Workspaces on the portrait monitor scroll top-to-bottom (see WORKSPACES below)
local function is_vertical_ws(id)
    return id >= 6 and id <= 10
end

-- Which arrow layout the window's keys should use. A scratchpad window follows the monitor
-- the scratchpad is open on, so stash/unstash are on the same axis on the portrait monitor.
local function uses_portrait_keys(win)
    if win == nil then
        return false
    end
    if win.workspace.special then
        return win.monitor.description == SIDE_DESC
    end
    return is_vertical_ws(win.workspace.id)
end

-- Focus the next/previous column along the tape, whichever way the workspace scrolls
local function focus_along(forward)
    return function()
        local win = hl.get_active_window()
        local vertical = win ~= nil and is_vertical_ws(win.workspace.id)
        local dir
        if vertical then
            dir = forward and "down" or "up"
        else
            dir = forward and "right" or "left"
        end
        -- Stay on the workspace: at either end of the tape do nothing. Plain "focus" would hop to
        -- the other monitor off the first column, or bounce back a column off the last one
        if win ~= nil and not win.floating then
            local axis = vertical and "y" or "x"
            local pos = win.at[axis]
            local at_end = true
            for _, c in ipairs(hl.get_workspace_windows(win.workspace.id)) do
                local p = c.at[axis]
                if not c.floating and (forward and p > pos or not forward and p < pos) then
                    at_end = false
                    break
                end
            end
            if at_end then
                return
            end
        end
        hl.dispatch(hl.dsp.focus({ direction = dir }))
    end
end

-- Super+scroll moves focus between columns (scrolling layout);
-- Super+Shift+scroll keeps the old workspace switching
hl.unbind(mainMod .. " + mouse_down")
hl.unbind(mainMod .. " + mouse_up")
hl.bind(mainMod .. " + mouse_down",         focus_along(true),  { description = "Windows: focus the next column (along the tape)" })
hl.bind(mainMod .. " + mouse_up",           focus_along(false), { description = "Windows: focus the previous column (along the tape)" })
hl.bind(mainMod .. " + Tab",                focus_along(true),  { repeating = true, description = "Windows: focus the next column (along the tape)" })
hl.bind(mainMod .. " + SHIFT + Tab",        focus_along(false), { repeating = true, description = "Windows: focus the previous column (along the tape)" })

-- Super+Shift+S (default "move to scratchpad", a toggle) is replaced by the arrow keys:
-- Super+Shift+Down/Up, or Left/Right on the portrait monitor
hl.unbind(mainMod .. " + SHIFT + S")

-- Stack the window into the neighbouring column, or pop it back out if already stacked
hl.bind(mainMod .. " + bracketleft",  hl.dsp.layout("consume_or_expel prev"), { description = "Windows: stack into the previous column, or pop back out" })
hl.bind(mainMod .. " + bracketright", hl.dsp.layout("consume_or_expel next"), { description = "Windows: stack into the next column, or pop back out" })
hl.bind(mainMod .. " + SHIFT + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspaces: next workspace" })
hl.bind(mainMod .. " + SHIFT + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), { description = "Workspaces: previous workspace" })

-- Windows
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "fullscreen" }), { description = "Windows: fullscreen" })
hl.bind(mainMod .. " + SHIFT + F",   hl.dsp.window.fullscreen({ mode = "maximized" }), { description = "Windows: maximize" })
-- Super+M was "exit Hyprland" by default; log out via the power menu (Super+Esc) instead
hl.unbind(mainMod .. " + M")
hl.bind(mainMod .. " + M",           hl.dsp.window.fullscreen({ mode = "maximized" }), { description = "Windows: maximize" })

-- Super(+Shift)+arrows drive the scrolling tape. On the portrait monitor the arrows are
-- turned 90° so they follow the tape: left->up, right->down, up->right, down->left.
--
--   action                 landscape (1-5)     portrait (6-10)
--   move column back/fwd   Super+Left/Right    Super+Up/Down
--   maximize toggle        Super+Up            Super+Right
--   (nothing)              Super+Down          Super+Left
--   shrink/grow column     Super+Shift+L/R     Super+Shift+Up/Down
--   back from scratchpad   Super+Shift+Up      Super+Shift+Right
--   send to scratchpad     Super+Shift+Down    Super+Shift+Left
local tape_actions = {
    back     = function() return hl.dsp.layout("swapcol l") end,
    forward  = function() return hl.dsp.layout("swapcol r") end,
    maximize = function() return hl.dsp.window.fullscreen({ mode = "maximized" }) end,
    shrink   = function() return hl.dsp.layout("colresize -0.05") end,
    grow     = function() return hl.dsp.layout("colresize +0.05") end,
    unstash  = function() return hl.dsp.window.move({ workspace = "e+0" }) end,
    stash    = function()
        -- Already in the scratchpad: do nothing (Hyprland would move it back out)
        local win = hl.get_active_window()
        if win ~= nil and win.workspace.special then
            return nil
        end
        return hl.dsp.window.move({ workspace = "special:magic" })
    end,
}

-- What each action is called in the keybinds panel (Super+K)
local tape_labels = {
    back     = "move column back",
    forward  = "move column forward",
    maximize = "maximize",
    shrink   = "shrink column",
    grow     = "grow column",
    unstash  = "take window out of the scratchpad",
    stash    = "send window to the scratchpad",
    none     = "unused",
}

-- { key, landscape action, portrait action, repeating }
local tape_binds = {
    { "left",          "back",     "none" },
    { "right",         "forward",  "maximize" },
    { "up",            "maximize", "back" },
    { "down",          "none",     "forward" },
    { "SHIFT + left",  "shrink",   "stash",   true },
    { "SHIFT + right", "grow",     "unstash", true },
    { "SHIFT + up",    "unstash",  "shrink",  true },
    { "SHIFT + down",  "stash",    "grow",    true },
}

for _, b in ipairs(tape_binds) do
    local key, landscape, portrait, repeating = b[1], b[2], b[3], b[4]
    hl.unbind(mainMod .. " + " .. key)
    hl.bind(mainMod .. " + " .. key, function()
        local action = uses_portrait_keys(hl.get_active_window()) and portrait or landscape
        local make = tape_actions[action] -- nil for "none": key unused in this orientation
        local dispatcher = make and make()
        if dispatcher then
            hl.dispatch(dispatcher)
        end
    end, {
        repeating = repeating or nil, -- held resize repeats; a repeated stash/unstash is a no-op
        description = "Windows: " .. tape_labels[landscape] .. " on landscape · " .. tape_labels[portrait] .. " on portrait",
    })
end

-- Don't wrap the first column to the end (and vice versa) when reordering
hl.config({
    scrolling = {
        wrap_swapcol = false,
    },
})


---------------------
---- WORKSPACES  ----
---------------------

-- Fixed workspaces: 1-5 on the main monitor, 6-10 on the portrait one.
-- Super+[digit] / Super+Shift+[digit] come from hyprland.lua and jump to the right monitor.
for i = 1, 10 do
    hl.workspace_rule({
        workspace  = tostring(i),
        monitor    = i <= 5 and MAIN or SIDE,
        persistent = true,
        default    = (i == 1 or i == 6),
        -- Portrait monitor: windows stack top-to-bottom instead of left-to-right
        layout_opts = is_vertical_ws(i) and { direction = "down" } or nil,
    })
end

-- Super + volume keys control the default microphone (Scarlett Input 2 Mic).
-- This is PipeWire's software level, on top of the interface's gain knob; capped at 100%.
hl.bind(mainMod .. " + XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, description = "Audio: mute / unmute the microphone" })
hl.bind(mainMod .. " + XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SOURCE@ 5%+"), { locked = true, repeating = true, description = "Audio: microphone level +5%" })
hl.bind(mainMod .. " + XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%-"), { locked = true, repeating = true, description = "Audio: microphone level -5%" })

-- Media keys go through the shell (shows OSD, picks active player)
local media_descriptions = {
    mediaToggle = "Media: play / pause",
    mediaNext   = "Media: next track",
    mediaPrev   = "Media: previous track",
}
for key, action in pairs({
    XF86AudioPlay  = "mediaToggle",
    XF86AudioPause = "mediaToggle",
    XF86AudioNext  = "mediaNext",
    XF86AudioPrev  = "mediaPrev",
}) do
    hl.unbind(key)
    hl.bind(key, hl.dsp.global("caelestia:" .. action), { locked = true, description = media_descriptions[action] })
end


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    name  = "float-dialogs",
    match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|nm-connection-editor|nwg-look|qt6ct|kvantummanager)$" },
    float = true,
    size  = "monitor_w*0.6 monitor_h*0.7",
    center = true,
})

hl.window_rule({
    name  = "imv-float",
    match = { class = "^imv$" },
    float = true,
    center = true,
})

hl.window_rule({
    -- Tiled like everything else, just a narrow column
    name            = "steam-friends-narrow",
    match           = { class = "^steam$", title = "^Friends List$" },
    scrolling_width = 0.15,
})

-- Don't lock/blank while gaming: gamepad input doesn't count as activity, and Caelestia's
-- idle timeouts respect inhibitors. Anything fullscreen (videos too); Steam games whenever focused.
-- Order matters: the later matching rule's idle_inhibit wins, so the catch-all goes first
hl.window_rule({
    name         = "fullscreen-no-idle",
    match        = { class = ".*" },
    idle_inhibit = "fullscreen",
})

hl.window_rule({
    name         = "steam-games-no-idle",
    match        = { class = "^steam_app_.*$" },
    idle_inhibit = "focus",
})

-- Steam games open in their own scratchpad (special:games), toggled with Super+G.
-- Matched by class, not fullscreen state: workspace only applies when the window maps,
-- and most games map windowed and go fullscreen afterwards
hl.window_rule({
    name      = "steam-games-scratchpad",
    match     = { class = "^steam_app_.*$" },
    workspace = "special:games",
})
hl.bind(mainMod .. " + G", hl.dsp.workspace.toggle_special("games"), { description = "Workspaces: games scratchpad (Steam games open there)" })

-- Caelestia's game mode (no animations/blur/gaps/shadows, tearing allowed) follows the games
-- scratchpad: on when a window opens there, off when the last one closes. Keyed on the
-- workspace, so adding a class to the rule above is enough. Only these two transitions touch
-- it, so toggling game mode by hand still works while no game is open
local function in_games(win)
    return win ~= nil and win.workspace ~= nil and win.workspace.name == "special:games"
end

local function game_mode(state)
    hl.dispatch(hl.dsp.exec_cmd("qs -c caelestia ipc call gameMode " .. state))
end

hl.on("window.open", function(win)
    if in_games(win) then
        game_mode("enable")
    end
end)

hl.on("window.close", function(win)
    if not in_games(win) then
        return
    end
    -- The closing window is still listed here
    for _, other in ipairs(hl.get_windows()) do
        if other.address ~= win.address and in_games(other) then
            return
        end
    end
    game_mode("disable")
end)

-- Manual toggle (e.g. a non-Steam game the rule doesn't catch)
hl.bind(mainMod .. " + SHIFT + G", function() game_mode("toggle") end, { description = "Workspaces: Caelestia game mode on / off (also automatic with the games scratchpad)" })
