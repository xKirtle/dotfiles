#!/bin/bash
# Move active window to local workspace N (1..9) on the focused monitor.
set -euo pipefail

N="${1:-}"; [[ "$N" =~ ^[1-9]$ ]] || { echo "need 1..9"; exit 1; }
command -v jq >/dev/null || { notify-send "Install jq"; exit 1; }

MAPFILE="$HOME/.config/hypr/.ws_map.json"
mkdir -p "$(dirname "$MAPFILE")"
[[ -f "$MAPFILE" ]] || echo '{}' > "$MAPFILE"

MON=$(hyprctl -j monitors | jq -r '.[] | select(.focused==true).name')

# Discover Nth numeric WS on this monitor first.
mapfile -t WS_ON_MON < <(
  hyprctl -j workspaces \
  | jq -r --arg mon "$MON" '[.[] | select(.monitor==$mon) | select(.name|test("^[0-9]+$")) | .name | tonumber] | sort | map(tostring) | .[]'
)

IDX=$((N-1))
if (( ${#WS_ON_MON[@]} > IDX )); then
  TARGET="${WS_ON_MON[$IDX]}"
else
  GLOBAL_MAX=$(hyprctl -j workspaces | jq -r '[.[] | select(.name|test("^[0-9]+$")) | .name | tonumber] | if length==0 then 0 else max end')
  TARGET=$((GLOBAL_MAX + 1))
  hyprctl dispatch workspace "$TARGET"
  hyprctl dispatch moveworkspacetomonitor "$TARGET" "$MON" >/dev/null 2>&1 || true
fi

# Persist mapping for consistency with jump script
TMP=$(mktemp)
jq --arg m "$MON" --arg n "$N" --arg v "$TARGET" '.[ $m ] = ( .[ $m ] // {} ) | .[ $m ][ $n ] = $v' "$MAPFILE" > "$TMP"
mv "$TMP" "$MAPFILE"

# Move the active window
hyprctl dispatch movetoworkspace "$TARGET"