#!/bin/bash
# Usage: workspace-cycle-smart.sh up|down
# Behavior:
#  - Per focused monitor
#  - Up: stop if CURRENT WS is empty; else go to next numeric WS on this monitor; if none, create GLOBAL_MAX+1
#  - Down: go to previous numeric WS on this monitor; stop at the lowest numeric
#  - Non-numeric workspaces are ignored for sequencing

set -euo pipefail

DIRECTION="${1:-up}"

# Deps
command -v jq >/dev/null || { notify-send "Install 'jq' for ws-cycle"; exit 1; }
command -v hyprctl >/dev/null || { echo "hyprctl not found" >&2; exit 1; }

# Active monitor (respects follow-cursor)
ACTIVE_MONITOR=$(hyprctl -j monitors | jq -r '.[] | select(.focused==true).name')
[[ -n "$ACTIVE_MONITOR" ]] || exit 0

# Active workspace (id + name)
ACTIVE_WS_JSON=$(hyprctl -j activeworkspace)
CURRENT_ID=$(jq -r '.id' <<<"$ACTIVE_WS_JSON")
CURRENT_NAME=$(jq -r '.name' <<<"$ACTIVE_WS_JSON")

# Build numeric workspace list for this monitor, sorted ascending (as strings)
mapfile -t WS_NAMES < <(
  hyprctl -j workspaces \
  | jq -r --arg mon "$ACTIVE_MONITOR" '
      [.[] | select(.monitor==$mon) | select(.name|test("^[0-9]+$")) | .name]
      | map(tonumber) | sort | map(tostring) | .[]'
)

# If current is numeric but missing in list (rare), include and resort
if [[ "$CURRENT_NAME" =~ ^[0-9]+$ ]]; then
  if ! printf '%s\n' "${WS_NAMES[@]}" | grep -qx -- "$CURRENT_NAME"; then
    WS_NAMES+=("$CURRENT_NAME")
    mapfile -t WS_NAMES < <(printf '%s\n' "${WS_NAMES[@]}" | awk 'NF' | sort -n)
  fi
fi

# Current index within numeric list (or -1 if current is non-numeric/not found)
CUR_IDX=-1
if [[ "$CURRENT_NAME" =~ ^[0-9]+$ ]]; then
  for i in "${!WS_NAMES[@]}"; do
    [[ "${WS_NAMES[$i]}" == "$CURRENT_NAME" ]] && CUR_IDX=$i && break
  done
fi

# Count clients on current workspace (by ID to handle named workspaces too)
clients_json=$(hyprctl -j clients)
CURRENT_TILE_COUNT=$(jq --argjson id "$CURRENT_ID" '[.[] | select(.workspace.id==$id)] | length' <<<"$clients_json")

# Helper: compute global max numeric WS across all monitors
GLOBAL_MAX=$(hyprctl -j workspaces | jq -r '[.[] | select(.name|test("^[0-9]+$")) | .name | tonumber] | if length==0 then 0 else max end')

case "$DIRECTION" in
  up)
    # Stop at first empty workspace
    if [[ "$CURRENT_TILE_COUNT" -eq 0 ]]; then
      exit 0
    fi

    if [[ "$CUR_IDX" -ge 0 && $((CUR_IDX+1)) -lt ${#WS_NAMES[@]} ]]; then
      NEXT_NAME="${WS_NAMES[$((CUR_IDX+1))]}"
      hyprctl dispatch workspace "$NEXT_NAME"
      exit 0
    fi

    # No next on this monitor: create a new *global* next to avoid collisions on other monitors
    NEXT_NUM=$(( GLOBAL_MAX + 1 ))
    hyprctl dispatch workspace "$NEXT_NUM"
    ;;

  down)
    # Stop at lowest numeric workspace on this monitor
    if [[ "$CUR_IDX" -le 0 ]]; then
      exit 0
    fi
    PREV_NAME="${WS_NAMES[$((CUR_IDX-1))]}"
    hyprctl dispatch workspace "$PREV_NAME"
    ;;

  *)
    echo "Usage: $0 up|down" >&2
    exit 1
    ;;

esac