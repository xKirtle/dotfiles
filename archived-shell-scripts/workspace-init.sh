#!/usr/bin/env bash
set -euo pipefail

# Monitor descriptions exactly as in hyprland.conf (without "desc:")
DESC_A="${1:-LG Electronics LG ULTRAGEAR+ 411NTTQ06481}"
DESC_B="${2:-LG Electronics LG ULTRAGEAR+ 402NTJJB7972}"

LIB="${HOME}/.config/hypr/scripts/workspace-lib.sh"
source "$LIB"

mon_json="$(hyprctl -j monitors)"

# Resolve name+id by description (adjust if you prefer by .name)
mon_name_by_desc() {
  jq -r --arg d "$1" '.[] | select(.description==$d) | .name' <<<"$mon_json"
}
mon_id_by_desc() {
  jq -r --arg d "$1" '.[] | select(.description==$d) | .id' <<<"$mon_json"
}

MON_A_NAME="$(mon_name_by_desc "$DESC_A")"
MON_A_ID="$(mon_id_by_desc  "$DESC_A")"
MON_B_NAME="$(mon_name_by_desc "$DESC_B")"
MON_B_ID="$(mon_id_by_desc  "$DESC_B")"

ensure_slot1_on_monitor() {
  # $1=monitorName  $2=monitorId
  local MNAME="$1" MID="$2"

  # Focus the monitor so "current workspace" is *on that monitor*
  hyprctl dispatch focusmonitor "$MNAME" >/dev/null 2>&1 || true

  # Discover current ws name on that monitor
  local cur_ws monj
  monj="$(hyprctl -j monitors)"
  cur_ws="$(jq -r --arg n "$MNAME" '.[] | select(.name==$n) | .activeWorkspace.name' <<<"$monj")"

  # Compute what we *want* (wrapped local slot 1)
  local want_ws
  want_ws="$(ws_name_for_mid "$MID" 1)"

  # If already correct, we’re done
  if [[ "$cur_ws" == "$want_ws" ]]; then
    return 0
  fi

  # Try direct rename first (supported in recent Hyprland)
  if hyprctl dispatch renameworkspace "name:${cur_ws}" "$want_ws" >/dev/null 2>&1; then
    # Make sure focus ends up on the renamed (now canonical) ws
    hyprctl dispatch focusmonitor "$MNAME" >/dev/null 2>&1 || true
    hyprctl dispatch workspace "name:${want_ws}" >/dev/null 2>&1 || true
    return 0
  fi

  # Fallback path (older Hyprland):
  # 1) Create/call the target by name (this focuses it)
  hyprctl dispatch workspace "name:${want_ws}" >/dev/null 2>&1 || true
  # 2) Ensure it lives on the correct monitor
  hyprctl dispatch moveworkspacetomonitor "name:${want_ws}" "$MNAME" >/dev/null 2>&1 || true

  # Ensure focus on the target after the move
  hyprctl dispatch focusmonitor "$MNAME" >/dev/null 2>&1 || true
  hyprctl dispatch workspace "name:${want_ws}" >/dev/null 2>&1 || true

  # Move clients from the old ws (if it still exists) to the new one
  local wsj clj old_id
  wsj="$(hyprctl -j workspaces)"
  old_id="$(jq -r --arg n "$cur_ws" '(.[] | select(.name==$n) | .id) // empty' <<<"$wsj")"
  if [[ -n "$old_id" ]]; then
    clj="$(hyprctl -j clients)"
    mapfile -t addrs < <(jq -r --argjson id "$old_id" '.[] | select(.workspace.id==$id) | .address' <<<"$clj")
    for a in "${addrs[@]}"; do
      hyprctl dispatch movetoworkspacesilent "name:${want_ws}" "$a" >/dev/null 2>&1 || true
    done
    # Kill old ws if it became empty and is a plain numeric
    local left
    left="$(hyprctl -j clients | jq -r --argjson id "$old_id" '[.[] | select(.workspace.id==$id)] | length')"
    if [[ "$left" == "0" && "$cur_ws" =~ ^[0-9]+$ ]]; then
      hyprctl dispatch killworkspace "$cur_ws" >/dev/null 2>&1 || true
    fi
  fi
}

# Ensure slot 1 exists and is the *current* ws on each monitor
ensure_slot1_on_monitor "$MON_A_NAME" "$MON_A_ID"
ensure_slot1_on_monitor "$MON_B_NAME" "$MON_B_ID"

# Optional: focus back to A
hyprctl dispatch focusmonitor "$MON_A_NAME" >/dev/null 2>&1 || true
hyprctl dispatch workspace "name:$(ws_name_for_mid "$MON_A_ID" 1)" >/dev/null 2>&1 || true
