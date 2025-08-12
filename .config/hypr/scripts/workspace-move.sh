#!/usr/bin/env bash
# workspace-move.sh [--all] <1-9>
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/workspace-lib.sh"

MODE="one"
if [[ "${1:-}" == "--all" ]]; then MODE="all"; shift; fi

N="${1:-}"; [[ "$N" =~ ^[1-9]$ ]] || { echo "Usage: $0 [--all] <1-9>"; exit 1; }
command -v jq >/dev/null || { notify-send "Install jq"; exit 1; }

ws_focus || exit 0
ws_wsjson
ws_clients_json

SRC_WS_JSON="$(hyprctl -j activeworkspace)"
SRC_WS_ID="$(jq -r '.id' <<<"$SRC_WS_JSON")"
SRC_WS_NAME="$(jq -r '.name' <<<"$SRC_WS_JSON")"

TARGET_SLOT="$(ws_decide_target_move "$N" "$MODE" "$SRC_WS_ID")"
[[ -z "$TARGET_SLOT" ]] && exit 0

TARGET_NAME="$(ws_target_name_for_slot "$TARGET_SLOT")"
[[ "$TARGET_NAME" == "$SRC_WS_NAME" ]] && exit 0

# Ensure target is on this monitor
hyprctl dispatch moveworkspacetomonitor "name:${TARGET_NAME}" "$MNAME" >/dev/null 2>&1 || true

if [[ "$MODE" == "all" ]]; then
  # snapshot first
  readarray -t ADDRS < <(jq -r --argjson id "$SRC_WS_ID" '.[] | select(.workspace.id==$id) | .address' <<<"$CL_JSON")
  for addr in "${ADDRS[@]}"; do
    hyprctl dispatch movetoworkspacesilent "name:${TARGET_NAME},address:${addr}"
  done
else
  ACTIVE_ADDR="$(hyprctl -j activewindow | jq -r '.address // empty')"
  [[ -n "$ACTIVE_ADDR" ]] || exit 0
  hyprctl dispatch movetoworkspacesilent "name:${TARGET_NAME},address:${ACTIVE_ADDR}"
fi

hyprctl dispatch workspace "name:${TARGET_NAME}"
