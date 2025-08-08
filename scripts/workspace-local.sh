#!/bin/bash
# Usage: ws-local.sh [gap|max] <1-9>
# Jump to the Nth numeric workspace on the focused monitor.
# If fewer than N exist, allocate a new global workspace using either:
#  - max: GLOBAL_MAX+1 (default)
#  - gap: smallest unused global number
set -euo pipefail

ALLOC="${1:-max}"
if [[ "$ALLOC" == "gap" || "$ALLOC" == "max" ]]; then
  shift
else
  ALLOC="max"
fi
N="${1:-}"
[[ "$N" =~ ^[1-9]$ ]] || { echo "need 1..9"; exit 1; }

command -v jq >/dev/null || { notify-send "Install jq"; exit 1; }

MON=$(hyprctl -j monitors | jq -r '.[] | select(.focused==true).name')
[[ -n "$MON" ]] || exit 0

# Discover current numeric workspaces on this monitor
mapfile -t WS_ON_MON < <(
  hyprctl -j workspaces \
  | jq -r --arg mon "$MON" '[.[] | select(.monitor==$mon) | select(.name|test("^[0-9]+$")) | .name | tonumber] | sort | map(tostring) | .[]'
)

IDX=$((N-1))
if (( ${#WS_ON_MON[@]} > IDX )); then
  TARGET="${WS_ON_MON[$IDX]}"
  hyprctl dispatch workspace "$TARGET"
  exit 0
fi

next_free_gap() {
  local used i
  used=$(hyprctl -j workspaces | jq -r '.[] | select(.name|test("^[0-9]+$")) | .name' | sort -n | uniq)
  i=1; while :; do if ! grep -qx "$i" <<<"$used"; then echo "$i"; return; fi; i=$((i+1)); done
}
next_free_max() {
  hyprctl -j workspaces | jq -r '[.[] | select(.name|test("^[0-9]+$")) | .name | tonumber] | if length==0 then 1 else (max+1) end'
}
get_next_id() {
  if [[ "$ALLOC" == "gap" ]]; then next_free_gap; else next_free_max; fi
}

TARGET="$(get_next_id)"
# Create/switch; Hyprland should spawn on focused monitor; ensure placement just in case
hyprctl dispatch workspace "$TARGET"
hyprctl dispatch moveworkspacetomonitor "$TARGET" "$MON" >/dev/null 2>&1 || true