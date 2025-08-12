#!/usr/bin/env bash
set -euo pipefail

IMG="${1:-}"
[[ -n "$IMG" && -f "$IMG" ]] || { echo "Usage: $0 /path/to/image"; exit 1; }

CACHE="${HOME}/.cache/current_wallpaper"
mkdir -p "$(dirname "$CACHE")"
printf '%s' "$IMG" > "$CACHE"

# Ensure hyprpaper running
pgrep -x hyprpaper >/dev/null || { hyprpaper & disown; sleep 0.2; }

# Preload + set on every monitor
hyprctl hyprpaper preload "$IMG" >/dev/null 2>&1 || true
hyprctl -j monitors | jq -r '.[].name' | while read -r mon; do
  [[ -n "$mon" ]] || continue
  hyprctl hyprpaper wallpaper "$mon,$IMG" >/dev/null 2>&1 || true
done

# Regenerate theme + reload Waybar/SwayNC/Kitty now
"${HOME}/.config/hypr/scripts/theme-reload.sh"
