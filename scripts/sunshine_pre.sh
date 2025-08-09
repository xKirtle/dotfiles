#!/bin/bash
set -euo pipefail

command -v jq >/dev/null || { notify-send "Install jq"; exit 1; }

# Make sure HDMI-A-1 exists (creates framebuffer)
hyprctl keyword monitor "HDMI-A-1, 1920x1080@60, auto, 1"

# Focus HDMI-A-1 and ensure an empty workspace there (the game + Steam will share it)
hyprctl dispatch focusmonitor HDMI-A-1
hyprctl dispatch workspace emptym
# hyprctl keyword windowrule "maximize, class:steam"
TARGET_WS_NAME=$(hyprctl -j activeworkspace | jq -r '.name')

# Unset default window rules and set new ones for sunshine
hyprctl keyword windowrule "unset monitor, class:steam"
hyprctl keyword windowrule "unset monitor, class:steam_app_.*"
hyprctl keyword windowrule "unset workspace, class:steam_app_.*"

hyprctl keyword windowrule "monitor HDMI-A-1, class:steam"
hyprctl keyword windowrule "monitor HDMI-A-1, class:steam_app_.*"
# (no workspace rule for games -> they’ll open in the current WS we just focused)

# Move any already-open Steam windows to the target workspace on HDMI-A-1
mapfile -t ADDRS < <(hyprctl -j clients \
  | jq -r --arg ws "$TARGET_WS_NAME" '.[] | select((.class=="steam") or (.class|test("^steam_app_.*$"))) | .address')
for a in "${ADDRS[@]}"; do
  hyprctl dispatch movetoworkspacesilent "${TARGET_WS_NAME},address:${a}"
done

# Blank the other outputs for a dark room
hyprctl dispatch dpms off DP-2 || true
hyprctl dispatch dpms off DP-3 || true

# hyprctl dispatch "focuswindow class:steam" && hyprctl dispatch "fullscreenstate 0, class:steam" && sleep 0.1 && hyprctl dispatch "fullscreenstate 1, class:steam"
# hyprctl dispatch "focuswindow class:steam" && hyprctl dispatch "fullscreen 1 class:steam"