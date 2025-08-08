#!/bin/bash
# Usage: ws-local-moveall.sh [gap|max] <1-9>
# Moves ALL clients from the CURRENT workspace to the target local workspace N on the focused monitor,
# then switches to it. If N doesn't exist on that monitor, allocate a new global workspace using
# the selected strategy (default: max+1).
#
# Tips for layout preservation:
#  - Dwindle: set `dwindle:preserve_split = true` in your Hypr config for better ratio retention.
#  - Floating windows keep their geometry across moves.
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

# Current workspace (id + name)
ACTIVE_WS_JSON=$(hyprctl -j activeworkspace)
CUR_ID=$(jq -r '.id' <<<"$ACTIVE_WS_JSON")
CUR_NAME=$(jq -r '.name' <<<"$ACTIVE_WS_JSON")

# Helper: list numeric workspaces on this monitor
mapfile -t WS_ON_MON < <(
  hyprctl -j workspaces \
  | jq -r --arg mon "$MON" '[.[] | select(.monitor==$mon) | select(.name|test("^[0-9]+$")) | .name | tonumber] | sort | map(tostring) | .[]'
)

# Determine target workspace number for local index N
IDX=$((N-1))
if (( ${#WS_ON_MON[@]} > IDX )); then
  TARGET="${WS_ON_MON[$IDX]}"
else
  next_free_gap() {
    local used i
    used=$(hyprctl -j workspaces | jq -r '.[] | select(.name|test("^[0-9]+$")) | .name' | sort -n | uniq)
    i=1; while :; do if ! grep -qx "$i" <<<"$used"; then echo "$i"; return; fi; i=$((i+1)); done
  }
  next_free_max() {
    hyprctl -j workspaces | jq -r '[.[] | select(.name|test("^[0-9]+$")) | .name | tonumber] | if length==0 then 1 else (max+1) end'
  }
  if [[ "$ALLOC" == "gap" ]]; then TARGET=$(next_free_gap); else TARGET=$(next_free_max); fi
  # Create & pin to focused monitor (in case Hypr spawns elsewhere)
  hyprctl dispatch workspace "$TARGET"
  hyprctl dispatch moveworkspacetomonitor "$TARGET" "$MON" >/dev/null 2>&1 || true
fi

# If target equals current, nothing to do
[[ "$TARGET" == "$CUR_NAME" ]] && exit 0

# Collect all clients on the current workspace (addresses). Keep order; Hyprland will try to preserve layout.
mapfile -t ADDRS < <(hyprctl -j clients | jq -r --argjson id "$CUR_ID" '.[] | select(.workspace.id==$id) | .address')

# Move them silently to the target
for addr in "${ADDRS[@]}"; do
  hyprctl dispatch movetoworkspacesilent "$TARGET,address:$addr"
done

# Finally, switch to the target workspace
hyprctl dispatch workspace "$TARGET"