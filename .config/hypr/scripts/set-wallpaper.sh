#!/usr/bin/env bash
set -euo pipefail

IMG="${1:-}"
[[ -n "$IMG" && -f "$IMG" ]] || { echo "Usage: $0 /path/to/image"; exit 1; }
if rp="$(realpath -m -- "$IMG" 2>/dev/null)"; then IMG="$rp"; fi

# Ensure hyprpaper is running
pgrep -x hyprpaper >/dev/null || { hyprpaper & disown; sleep 0.2; }

# Preload + set on all monitors
hyprctl hyprpaper preload "$IMG" >/dev/null 2>&1 || true
hyprctl -j monitors | jq -r '.[].name' | while read -r mon; do
  [[ -n "$mon" ]] || continue
  hyprctl hyprpaper wallpaper "$mon,$IMG" >/dev/null 2>&1 || true
done

# Cache the current wallpaper so theme-reload can see it
WPF_FILE="$HOME/.cache/current_wallpaper"
mkdir -p -- "$(dirname "$WPF_FILE")"
printf '%s\n' "$IMG" > "$WPF_FILE"

ln -sTfn -- "$IMG" "$HOME/.cache/current_wallpaper.jpg"

# Kick theme reload (it will decide whether to regenerate)
"$HOME/.config/hypr/scripts/theme-reload.sh"
