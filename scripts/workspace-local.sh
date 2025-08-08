#!/bin/bash
# Jump to local workspace N (1..9) on the focused monitor.
# If the Nth numeric WS already exists on that monitor, go there.
# Otherwise create a new global WS (global max + 1) and bind it to local N for that monitor.
set -euo pipefail

N="${1:-}"; [[ "$N" =~ ^[1-9]$ ]] || { echo "need 1..9"; exit 1; }
command -v jq >/dev/null || { notify-send "Install jq"; exit 1; }

MAPFILE="$HOME/.config/hypr/.ws_map.json"
mkdir -p "$(dirname "$MAPFILE")"
[[ -f "$MAPFILE" ]] || echo '{}' > "$MAPFILE"

MON=$(hyprctl -j monitors | jq -r '.[] | select(.focused==true).name')
[[ -n "$MON" ]] || exit 0

# 1) Discover current numeric workspaces on this monitor, sorted.
mapfile -t WS_ON_MON < <(
  hyprctl -j workspaces \
  | jq -r --arg mon "$MON" '[.[] | select(.monitor==$mon) | select(.name|test("^[0-9]+$")) | .name | tonumber] | sort | map(tostring) | .[]'
)

# 2) If we already have at least N numeric WS here, use the Nth one directly.
IDX=$((N-1))
if (( ${#WS_ON_MON[@]} > IDX )); then
  TARGET="${WS_ON_MON[$IDX]}"
  hyprctl dispatch workspace "$TARGET"
  # Sync mapping so local N points to current real number.
  TMP=$(mktemp)
  jq --arg m "$MON" --arg n "$N" --arg v "$TARGET" '.[ $m ] = ( .[ $m ] // {} ) | .[ $m ][ $n ] = $v' "$MAPFILE" > "$TMP"
  mv "$TMP" "$MAPFILE"
  exit 0
fi

# 3) Otherwise allocate a new global workspace (guaranteed unused) and pin it to this monitor.
GLOBAL_MAX=$(hyprctl -j workspaces | jq -r '[.[] | select(.name|test("^[0-9]+$")) | .name | tonumber] | if length==0 then 0 else max end')
NEW=$((GLOBAL_MAX + 1))

# Create/switch; Hyprland will spawn it on the focused monitor. Force move just in case.
hyprctl dispatch workspace "$NEW"
hyprctl dispatch moveworkspacetomonitor "$NEW" "$MON" >/dev/null 2>&1 || true

# Save mapping
TMP=$(mktemp)
jq --arg m "$MON" --arg n "$N" --arg v "$NEW" '.[ $m ] = ( .[ $m ] // {} ) | .[ $m ][ $n ] = $v' "$MAPFILE" > "$TMP"
mv "$TMP" "$MAPFILE"