#!/usr/bin/env bash
# workspace-move.sh [--all] <1-9>
# Move active client (default) or ALL clients (--all) from the current workspace
# to the Nth *local slot* on the focused monitor.
# Rules:
# - Target slot is resolved like workspace-goto (clamp to max+1; respect last_occupied+1; holes no-op).
# - EXTRA GUARD: if the move would EMPTY the source workspace and the target
#   slot number is HIGHER than the source slot number, block the move.
#   (For --all it always empties; for single move, empties only if src has exactly 1 client.)

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/workspace-lib.sh"

MODE="one"
if [[ "${1:-}" == "--all" ]]; then MODE="all"; shift; fi

N="${1:-}"; [[ "$N" =~ ^[1-9]$ ]] || { echo "Usage: $0 [--all] <1-9>"; exit 1; }
command -v jq >/dev/null || { notify-send "Install jq"; exit 1; }

# Focused monitor
MONS=$(hyprctl -j monitors)
MID=$(jq -r '.[] | select(.focused==true).id' <<<"$MONS")
MNAME=$(jq -r '.[] | select(.focused==true).name' <<<"$MONS")
[[ "$MID" != "null" && -n "$MNAME" ]] || exit 0

# Snapshots
WS_JSON=$(hyprctl -j workspaces)
CL_JSON=$(hyprctl -j clients)
SRC_WS=$(hyprctl -j activeworkspace)
SRC_WS_ID=$(jq -r '.id' <<<"$SRC_WS")
SRC_WS_NAME=$(jq -r '.name' <<<"$SRC_WS")

# Current local slot number
SRC_SLOT=""
if [[ "$SRC_WS_NAME" =~ ^[0-9]+$ ]]; then
  if jq -e --arg mon "$MNAME" --arg n "$SRC_WS_NAME" 'any(.[]; .monitor==$mon and .name==$n)' >/dev/null <<<"$WS_JSON"; then
    SRC_SLOT="$SRC_WS_NAME"
  fi
elif ws_is_for_mid "$MID" "$SRC_WS_NAME"; then
  SRC_SLOT="$(printf '%s' "$SRC_WS_NAME" | ws_strip_invis)"
fi

# If you're already on the requested local slot, no-op
[[ "$SRC_SLOT" == "$N" ]] && exit 0

# Helpers
ws_target_name_for_slot () {
  local slot="$1"
  local found
  found=$(jq -r --arg mon "$MNAME" --arg n "$slot" \
          '.[] | select(.monitor==$mon and .name==$n) | .name' <<<"$WS_JSON")
  if [[ -n "$found" ]]; then printf '%s' "$found"; else ws_name_for_mid "$MID" "$slot"; fi
}
slot_exists () {
  local slot="$1"
  jq -e --arg mon "$MNAME" --arg n "$slot" 'any(.[]; .monitor==$mon and .name==$n)' >/dev/null <<<"$WS_JSON" && return 0
  local w; w="$(ws_name_for_mid "$MID" "$slot")"
  jq -e --arg w "$w" 'any(.[]; .name==$w)' >/dev/null <<<"$WS_JSON"
}

# Local existing slots → MAX_EXIST
readarray -t SLOTS_NUM < <(jq -r --arg mon "$MNAME" '.[] | select(.monitor==$mon) | .name' <<<"$WS_JSON" | grep -E '^[0-9]+$' || true)
readarray -t SLOTS_WRP < <(jq -r '.[].name' <<<"$WS_JSON" | while read -r n; do ws_is_for_mid "$MID" "$n" && printf '%s\n' "$n" | ws_strip_invis || true; done)
readarray -t SLOTS < <(printf "%s\n" "${SLOTS_NUM[@]}" "${SLOTS_WRP[@]}" | grep -E '^[0-9]+$' | sort -n | uniq)
MAX_EXIST=0; ((${#SLOTS[@]})) && MAX_EXIST="${SLOTS[-1]}"

# Highest OCCUPIED local slot (has at least one client) on THIS monitor
LAST_OCC=$(jq -r --arg mon "$MNAME" --argjson ws "$WS_JSON" '
  def strip: gsub("\u200b|\u200c|\u200d|\u2060|\u200e|\u200f";"");
  [ .[] as $c
    | ($ws[] | select(.id == $c.workspace.id)) as $w
    | select($w.monitor == $mon)
    | ($w.name | strip)
    | select(test("^[0-9]+$"))
    | tonumber
  ] | max? // 0
' <<<"$CL_JSON")

# Resolve TARGET_SLOT using the same clamping as workspace-goto
TARGET_SLOT=""
if slot_exists "$N"; then
  TARGET_SLOT="$N"
else
  if (( N > MAX_EXIST + 1 )); then
    TARGET_SLOT=$((MAX_EXIST + 1))
  elif (( N == MAX_EXIST + 1 )); then
    TARGET_SLOT=$N
  elif (( N > LAST_OCC + 1 )); then
    TARGET_SLOT=$((LAST_OCC + 1))
  else
    # N <= MAX_EXIST but missing (a hole) → no-op
    exit 0
  fi
fi

# ----- EXTRA GUARD: block moves that would EMPTY the source when moving "up" -----
# Source client count (how many would remain after moving)
SRC_COUNT=$(jq -r --argjson id "$SRC_WS_ID" '[ .[] | select(.workspace.id==$id) ] | length' <<<"$CL_JSON")
EMPTIES_SOURCE=0
if [[ "$MODE" == "all" ]]; then
  EMPTIES_SOURCE=1
else
  # moving one: empties iff there is exactly 1 client
  (( SRC_COUNT == 1 )) && EMPTIES_SOURCE=1 || EMPTIES_SOURCE=0
fi

# If moving to a strictly higher local slot and it would empty the source -> BLOCK
if (( EMPTIES_SOURCE == 1 )) && [[ -n "$SRC_SLOT" ]] && (( TARGET_SLOT > SRC_SLOT )); then
  exit 0
fi
# -------------------------------------------------------------------------------

TARGET_NAME="$(ws_target_name_for_slot "$TARGET_SLOT")"
[[ "$TARGET_NAME" == "$SRC_WS_NAME" ]] && exit 0  # nothing to move

# Create/pin target (creation can happen implicitly), then move by address
hyprctl dispatch moveworkspacetomonitor "name:${TARGET_NAME}" "$MNAME" >/dev/null 2>&1 || true

if [[ "$MODE" == "all" ]]; then
  # Snapshot source addresses BEFORE moving
  readarray -t ADDRS < <(jq -r --argjson id "$SRC_WS_ID" '.[] | select(.workspace.id==$id) | .address' <<<"$CL_JSON")
  for addr in "${ADDRS[@]}"; do
    hyprctl dispatch movetoworkspacesilent "name:${TARGET_NAME},address:${addr}"
  done
else
  ACTIVE_ADDR=$(hyprctl -j activewindow | jq -r '.address // empty')
  [[ -n "$ACTIVE_ADDR" ]] || exit 0
  hyprctl dispatch movetoworkspacesilent "name:${TARGET_NAME},address:${ACTIVE_ADDR}"
fi

# Focus the target
hyprctl dispatch workspace "name:${TARGET_NAME}"
