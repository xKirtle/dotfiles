#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_FILE="${HOME}/.cache/current_wallpaper"   # optional; keep if you use it elsewhere
HYPR_COLORS="$HOME/.config/hypr/colors.conf"
WAYBAR_CSS="$HOME/.config/waybar/colors.css"
SWAYNC_CSS="$HOME/.config/swaync/colors.css"
GTK3_CSS="$HOME/.config/gtk-3.0/colors.css"
GTK4_CSS="$HOME/.config/gtk-4.0/colors.css"
WLOGOUT_CSS="$HOME/.config/wlogout/colors.css"
WOFI_CSS="$HOME/.config/wofi/style.css"
KITTY_COLORS="$HOME/.config/kitty/colors-wallust.conf"

reload_kitty(){ kitty @ set-colors --all "$KITTY_COLORS" >/dev/null 2>&1 || true; }
notif(){ notify-send -t 1200 "Theme" "$1" || true; }

inotifywait -m -e close_write,create,move \
  "$HYPR_COLORS" "$WAYBAR_CSS" "$SWAYNC_CSS" \
  "$GTK3_CSS" "$GTK4_CSS" "$WLOGOUT_CSS" "$WOFI_CSS" "$KITTY_COLORS" 2>/dev/null |
while read -r path ev file; do
  case "$path$file" in
    "$WAYBAR_CSS") pkill -SIGUSR2 waybar 2>/dev/null || waybar & disown; notif "Waybar reloaded" ;;
    "$SWAYNC_CSS") pgrep -x swaync >/dev/null && swaync-client -rs >/dev/null 2>&1 || true ;;
    "$HYPR_COLORS") hyprctl reload >/dev/null 2>&1 || true ;;
    "$GTK3_CSS"|"$GTK4_CSS") notif "GTK apps may need restart" ;;
    "$WLOGOUT_CSS") notif "wlogout theme applies on next launch" ;;
    "$WOFI_CSS") notif "Wofi theme applies on next run" ;;
    "$KITTY_COLORS") reload_kitty; notif "Kitty colors reloaded" ;;
  esac
done