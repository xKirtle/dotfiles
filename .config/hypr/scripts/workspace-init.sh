#!/usr/bin/env bash
set -euo pipefail

# Monitor descriptions exactly as in hyprland.conf (without "desc:")
DESC_A="${1:-LG Electronics LG ULTRAGEAR+ 411NTTQ06481}"
DESC_B="${2:-LG Electronics LG ULTRAGEAR 310NTCZ6H379}"

# Source workspace-lib so we use the *same* wrapper logic
LIB="${HOME}/.config/hypr/scripts/workspace-lib.sh"
source "$LIB"

# Find monitor names & ids by description
MONS="$(hyprctl -j monitors)"
MON_A_NAME="$(jq -r --arg d "$DESC_A" '.[] | select(.description==$d) | .name' <<<"$MONS")"
MON_A_ID="$(jq -r   --arg d "$DESC_A" '.[] | select(.description==$d) | .id'   <<<"$MONS")"
MON_B_NAME="$(jq -r --arg d "$DESC_B" '.[] | select(.description==$d) | .name' <<<"$MONS")"
MON_B_ID="$(jq -r   --arg d "$DESC_B" '.[] | select(.description==$d) | .id'   <<<"$MONS")"
[[ -n "$MON_A_NAME" && -n "$MON_B_NAME" && "$MON_A_ID" != "null" && "$MON_B_ID" != "null" ]] || exit 0

# Build the correct names using ws-lib's wrappers
WS_A="name:$(ws_name_for_mid "$MON_A_ID" 1)"
WS_B="name:$(ws_name_for_mid "$MON_B_ID" 1)"

# Create/activate and pin each to its monitor
hyprctl dispatch workspace "$WS_A"
hyprctl dispatch moveworkspacetomonitor "$WS_A" "$MON_A_NAME" || true

hyprctl dispatch workspace "$WS_B"
hyprctl dispatch moveworkspacetomonitor "$WS_B" "$MON_B_NAME" || true

# Focus back to A (optional)
hyprctl dispatch workspace "$WS_A"

# Optional: clean up auto numeric 1/2 if empty
wsj="$(hyprctl -j workspaces)"
for n in 1 2; do
  if jq -e --arg n "$n" 'any(.[]; .name==$n)' >/dev/null <<<"$wsj"; then
    wid="$(jq -r --arg n "$n" '.[] | select(.name==$n) | .id' <<<"$wsj")"
    ccount="$(hyprctl -j clients | jq -r --argjson wid "$wid" '[.[] | select(.workspace.id==$wid)] | length')"
    [[ "$ccount" == "0" ]] && hyprctl dispatch killworkspace "$n" || true
  fi
done
