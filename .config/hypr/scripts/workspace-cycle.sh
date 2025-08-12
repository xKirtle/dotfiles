#!/usr/bin/env bash
# workspace-cycle.sh up|down
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/workspace-lib.sh"

DIR="${1:-up}"
command -v jq >/dev/null || { notify-send "Install jq"; exit 1; }

ws_focus || exit 0
ws_wsjson
ws_clients_json

# Local existing slots, current, boundaries
mapfile -t SLOTS < <(ws_list_existing_local_slots)
CUR="$(ws_current_local_slot)"

FIRST_EXIST=0
MAX_EXIST=0
((${#SLOTS[@]})) && FIRST_EXIST="${SLOTS[0]}"
((${#SLOTS[@]})) && MAX_EXIST="${SLOTS[-1]}"

LAST_OCC="$(ws_last_occupied)"
NEXT_ALLOWED=$(( (LAST_OCC == 0) ? (MAX_EXIST + 1) : (LAST_OCC + 1) ))

goto_slot_num() { ws_goto_slot "$1"; }

if [[ "$DIR" == "down" ]]; then
  [[ -z "$CUR" ]] && exit 0
  prev=""
  for s in "${SLOTS[@]}"; do
    (( s < CUR )) && prev="$s" || break
  done
  if [[ -n "$prev" ]]; then
    goto_slot_num "$prev"
    exit 0
  fi
  # wrap: go to NEXT_ALLOWED (create if needed)
  goto_slot_num "$NEXT_ALLOWED"
  exit 0
fi

# up
if [[ -n "$CUR" ]]; then
  for s in "${SLOTS[@]}"; do
    if (( s > CUR )); then
      goto_slot_num "$s"
      exit 0
    fi
  done
fi

# No next existing
if [[ -n "$CUR" ]] && (( CUR == NEXT_ALLOWED )) && (( FIRST_EXIST > 0 )); then
  # wrap to first
  goto_slot_num "$FIRST_EXIST"
  exit 0
fi

if [[ -n "$CUR" ]] && (( CUR < NEXT_ALLOWED )); then
  goto_slot_num "$NEXT_ALLOWED"
  exit 0
fi

exit 0
