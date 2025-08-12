#!/usr/bin/env bash
set -euo pipefail

# Usage: set-wallpaper.sh /path/to/image [fill|fit|stretch|center|tile]
IMG="${1:-}"; MODE="${2:-fill}"

if [[ -z "$IMG" || ! -f "$IMG" ]]; then
  echo "Usage: $0 /path/to/image [mode]"; exit 1
fi

WALLPAPER_FILE="${HOME}/.cache/current_wallpaper"
mkdir -p "$(dirname "$WALLPAPER_FILE")"
printf '%s' "$IMG" > "$WALLPAPER_FILE"

# Kill any previous swaybg and start a new one (all outputs)
pkill -x swaybg >/dev/null 2>&1 || true
swaybg -o '*' -i "$IMG" -m "$MODE" & disown

# Apply theme (matugen + wallust), auto dark/light
"${HOME}/.config/hypr/scripts/theme-apply-from-wallpaper.sh" &
