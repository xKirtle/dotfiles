-- Minimal Hyprland used only to host the ReGreet login screen (run by greetd as user "greeter").
-- Exits as soon as ReGreet hands off to your session.

-- Same monitor layout as your desktop (from ~/.config/hypr/hyprland-gui.lua)
hl.monitor({ output = "desc:LG Electronics LG ULTRAGEAR+ 402NTJJB7972", mode = "3840x2160@144.05Hz", position = "0x0",     scale = 1.25, transform = 1 })
hl.monitor({ output = "desc:LG Electronics LG ULTRAGEAR+ 411NTTQ06481", mode = "3840x2160@240.08Hz", position = "1728x700", scale = 1.25 })
hl.monitor({ output = "",     mode = "preferred",          position = "auto",     scale = "auto" })

-- NVIDIA
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")

hl.config({
    general = {
        gaps_out    = 0,
        border_size = 0,
    },
    animations = {
        enabled = false,
    },
    input = {
        kb_layout   = "us,pt",
        kb_options  = "grp:lalt_lshift_toggle",
        sensitivity = -0.35,
        accel_profile = "flat",
    },
    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        background_color         = 0x1e1e2e, -- Catppuccin Mocha base
        disable_hyprland_guiutils_check = true,
    },
})

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
    hl.exec_cmd("regreet; hyprctl dispatch 'hl.dsp.exit()'")
end)

-- Show the login screen on the main monitor
hl.window_rule({
    name    = "regreet-main-monitor",
    match   = { class = "^apps\\.regreet$" },
    monitor = "desc:LG Electronics LG ULTRAGEAR+ 411NTTQ06481",
})
