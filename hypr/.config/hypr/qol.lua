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
    },
})


---------------------
---- KEYBINDINGS ----
---------------------

-- Caelestia launcher replaces hyprlauncher
hl.unbind(mainMod .. " + space")
hl.bind(mainMod .. " + space", hl.dsp.global("caelestia:launcher"))

hl.bind(mainMod .. " + L",           hl.dsp.global("caelestia:lock"))
hl.bind(mainMod .. " + Escape",      hl.dsp.global("caelestia:session"))
hl.bind(mainMod .. " + N",           hl.dsp.global("caelestia:sidebar"))
hl.bind(mainMod .. " + SHIFT + N",   hl.dsp.global("caelestia:clearNotifs"))
hl.bind(mainMod .. " + D",           hl.dsp.global("caelestia:showall"))

-- Keep awake: toggle Caelestia's idle inhibitor (no auto-lock / screen off), with a notification
-- saying the new state (the only other indicator is the "Keep awake" card in the utilities drawer)
hl.bind(mainMod .. " + SHIFT + I", hl.dsp.exec_cmd([[caelestia shell idleInhibitor toggle; if [ "$(caelestia shell idleInhibitor isEnabled)" = true ]; then notify-send -a caelestia-shell -i caffeine-cup-full "Keep awake: on" "The screen won't lock or turn off"; else notify-send -a caelestia-shell -i caffeine-cup-empty "Keep awake: off" "Auto-lock is back on"; fi]]))

-- Restart the shell if it ever dies
-- (wait for the old instance to fully exit, or the new one quits seeing it still running)
-- (match only Caelestia's qs, other Quickshell configs run too; '^' keeps it off this sh's own command line)
hl.bind("CTRL + " .. mainMod .. " + ALT + R", hl.dsp.exec_cmd("qs -c caelestia kill; for i in $(seq 50); do pgrep -f '^qs -c caelestia' >/dev/null || break; sleep 0.1; done; caelestia shell -d"), { release = true })

-- Screenshots: Print = region, Shift+Print = full screen, Super+Shift+S-style freeze
hl.bind("Print",                     hl.dsp.global("caelestia:screenshot"))
hl.bind("SHIFT + Print",             hl.dsp.exec_cmd("caelestia screenshot"))
hl.bind(mainMod .. " + Print",       hl.dsp.global("caelestia:screenshotFreeze"))
-- Ctrl+Print = record a region (gpu-screen-recorder via Caelestia); press again to stop
hl.bind("CTRL + Print",              hl.dsp.exec_cmd("caelestia record -r"))

-- Clipboard history / emoji picker / color picker
hl.bind(mainMod .. " + SHIFT + V",   hl.dsp.exec_cmd("pkill fuzzel || caelestia clipboard"))
hl.bind(mainMod .. " + period",      hl.dsp.exec_cmd("pkill fuzzel || caelestia emoji -p"))
hl.bind(mainMod .. " + SHIFT + C",   hl.dsp.exec_cmd("hyprpicker -a"))

-- Toggle audio output: Scarlett headphones <-> S/PDIF speakers
hl.bind(mainMod .. " + grave",       hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/cycle-audio-output.sh"))

-- Omarchy-style pickers: theme (scheme + its wallpaper) / wallpaper within the current theme
hl.bind("CTRL + SHIFT + " .. mainMod .. " + space", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/themectl picker themes"))
hl.bind("CTRL + " .. mainMod .. " + space",         hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/themectl picker wallpapers"))

-- Agenda panel: Proton Calendar, today + next days (calendar package, qs -c agenda)
hl.bind(mainMod .. " + A",           hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/calendarctl panel"))

-- Thunar picks up Caelestia's GTK theme (replaces dolphin)
hl.unbind(mainMod .. " + E")
hl.bind(mainMod .. " + E",           hl.dsp.exec_cmd("thunar"))

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
hl.bind(mainMod .. " + mouse_down",         focus_along(true))
hl.bind(mainMod .. " + mouse_up",           focus_along(false))
hl.bind(mainMod .. " + Tab",                focus_along(true),  { repeating = true })
hl.bind(mainMod .. " + SHIFT + Tab",        focus_along(false), { repeating = true })

-- Super+Shift+S (default "move to scratchpad", a toggle) is replaced by the arrow keys:
-- Super+Shift+Down/Up, or Left/Right on the portrait monitor
hl.unbind(mainMod .. " + SHIFT + S")

-- Stack the window into the neighbouring column, or pop it back out if already stacked
hl.bind(mainMod .. " + bracketleft",  hl.dsp.layout("consume_or_expel prev"))
hl.bind(mainMod .. " + bracketright", hl.dsp.layout("consume_or_expel next"))
hl.bind(mainMod .. " + SHIFT + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + SHIFT + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Windows
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mainMod .. " + SHIFT + F",   hl.dsp.window.fullscreen({ mode = "maximized" }))
-- Super+M was "exit Hyprland" by default; log out via the power menu (Super+Esc) instead
hl.unbind(mainMod .. " + M")
hl.bind(mainMod .. " + M",           hl.dsp.window.fullscreen({ mode = "maximized" }))

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
    end, repeating and { repeating = true } or nil) -- held resize repeats; a repeated stash/unstash is a no-op
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
hl.bind(mainMod .. " + XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),        { locked = true })
hl.bind(mainMod .. " + XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SOURCE@ 5%+"), { locked = true, repeating = true })
hl.bind(mainMod .. " + XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%-"),      { locked = true, repeating = true })

-- Media keys go through the shell (shows OSD, picks active player)
for key, action in pairs({
    XF86AudioPlay  = "mediaToggle",
    XF86AudioPause = "mediaToggle",
    XF86AudioNext  = "mediaNext",
    XF86AudioPrev  = "mediaPrev",
}) do
    hl.unbind(key)
    hl.bind(key, hl.dsp.global("caelestia:" .. action), { locked = true })
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
