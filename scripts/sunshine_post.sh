#!/bin/bash
set -euo pipefail

# hyprctl keyword windowrule "tile, class:steam"
# hyprctl dispatch "settiled class:steam" && hyprctl dispatch "closewindow class:steam"
# hyprctl dispatch "focuswindow class:steam" && hyprctl dispatch "fullscreen 1 class:steam"
# hyprctl keyword windowrule "tile, class:steam"
# hyprctl dispatch "togglefloating class:steam" && hyprctl dispatch "togglefloating class:steam"

# Wake real monitors
hyprctl dispatch dpms on DP-2 || true
hyprctl dispatch dpms on DP-3 || true

# hyprctl dispatch "focuswindow class:steam" && hyprctl dispatch "killactive"

# Unset window rules defined on the sunshine_pre script
hyprctl keyword windowrule "unset monitor, class:steam"
hyprctl keyword windowrule "unset monitor, class:steam_app_.*"
hyprctl keyword windowrule "unset workspace, class:steam_app_.*"

# Restore original default rules
hyprctl keyword windowrule "monitor DP-3, class:steam"
hyprctl keyword windowrule "monitor DP-3, class:steam_app_.*"
hyprctl keyword windowrule "workspace emptynm, class:steam_app_.*"

# Disable the capture output again
hyprctl keyword monitor "HDMI-A-1, disable"
