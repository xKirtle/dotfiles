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

# Existing local slots (sorted numeric)
mapfile -t SLOTS < <(ws_list_existing_local_slots)
COUNT=${#SLOTS[@]}
[[ $COUNT -eq 0 ]] && exit 0

CUR="$(ws_current_local_slot)"
# Find current index
cur_idx=-1
for i in "${!SLOTS[@]}"; do
  if [[ "${SLOTS[$i]}" == "$CUR" ]]; then cur_idx=$i; break; fi
done
[[ $cur_idx -lt 0 ]] && exit 0

FIRST="${SLOTS[0]}"
LAST="${SLOTS[-1]}"
LAST_OCC="$(ws_last_occupied)"
B=$(( LAST_OCC == 0 ? LAST + 1 : LAST_OCC + 1 ))  # active boundary slot number

goto_by_index () {
  local idx="$1"
  local tgt_slot
  tgt_slot="$(ws_decide_target_goto "$idx")"  # index semantics + “no-walk when empty”
  [[ -z "$tgt_slot" ]] && return 1
  ws_goto_slot "$tgt_slot"
  return 0
}

if [[ "$DIR" == "down" ]]; then
  # Previous existing
  if (( cur_idx > 0 )); then
    ws_goto_slot "${SLOTS[$((cur_idx-1))]}"
    exit 0
  fi
  # No previous → wrap
  if (( LAST_OCC == 0 )); then
    # all-empty: wrap to last existing (never create)
    ws_goto_slot "$LAST"
    exit 0
  fi
  # occupied: wrap to boundary B (force go-to; allow create even if current is empty)
  ws_goto_slot "$B"
  exit 0
fi

# ---- UP ----
# Next existing
if (( cur_idx + 1 < COUNT )); then
  ws_goto_slot "${SLOTS[$((cur_idx+1))]}"
  exit 0
fi

# No next existing → try “index COUNT+1” via goto logic
if goto_by_index $((COUNT+1)); then
  # If we just created/jumped to boundary, done
  exit 0
fi

# If goto logic no-oped (e.g., current is empty & it would step up), wrap to first
# Also: if we ARE already at the boundary, wrap to first
if (( CUR == B )) || true; then
  ws_goto_slot "$FIRST"
  exit 0
fi

exit 0
