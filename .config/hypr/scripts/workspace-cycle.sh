#!/usr/bin/env bash
# workspace-cycle.sh up|down
set -euo pipefail

# Resolve this script's directory, then source the lib from there
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/workspace-lib.sh"

DIR="${1:-up}"
command -v jq >/dev/null || { notify-send "Install jq"; exit 1; }

# Focused monitor
MONS=$(hyprctl -j monitors)
MID=$(jq -r '.[] | select(.focused==true).id' <<<"$MONS")
MNAME=$(jq -r '.[] | select(.focused==true).name' <<<"$MONS")
[[ "$MID" != "null" && -n "$MNAME" ]] || exit 0

WS_JSON=$(hyprctl -j workspaces)
CL_JSON=$(hyprctl -j clients)

# Local existing slots = numeric on THIS monitor ∪ wrapped-for-this-MID anywhere
mapfile -t SLOTS_NUM < <(jq -r --arg mon "$MNAME" \
  '.[] | select(.monitor==$mon) | .name' <<<"$WS_JSON" | grep -E '^[0-9]+$' || true)

mapfile -t SLOTS_WRP < <(jq -r '.[] | .name' <<<"$WS_JSON" | while read -r n; do
  ws_is_for_mid "$MID" "$n" && printf '%s\n' "$n" | ws_strip_invis || true
done)

# Merge unique, sort numeric
mapfile -t SLOTS < <(printf "%s\n" "${SLOTS_NUM[@]}" "${SLOTS_WRP[@]}" \
  | grep -E '^[0-9]+$' | sort -n | uniq)

# Current slot (numeric-on-this-monitor OR wrapped-for-this-MID)
CURNAME=$(hyprctl -j activeworkspace | jq -r '.name')
CUR_SLOT=""
if [[ "$CURNAME" =~ ^[0-9]+$ ]]; then
  if jq -e --arg mon "$MNAME" --arg n "$CURNAME" 'any(.[]; .monitor==$mon and .name==$n)' >/dev/null <<<"$WS_JSON"; then
    CUR_SLOT="$CURNAME"
  fi
elif ws_is_for_mid "$MID" "$CURNAME"; then
  CUR_SLOT="$(printf '%s' "$CURNAME" | ws_strip_invis)"
fi

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

# Current MIN/MAX existing local slots
FIRST_EXIST=0
MAX_EXIST=0
if ((${#SLOTS[@]})); then
  FIRST_EXIST="${SLOTS[0]}"
  MAX_EXIST="${SLOTS[-1]}"
fi

# NEXT_ALLOWED boundary (where creation is permitted)
if (( LAST_OCC == 0 )); then
  NEXT_ALLOWED=$((MAX_EXIST + 1))
else
  NEXT_ALLOWED=$((LAST_OCC + 1))
fi

# Helper: go to a specific slot (prefer numeric on this monitor, else wrapped)
goto_slot () {
  local slot="$1" tgt
  tgt=$(jq -r --arg mon "$MNAME" --arg n "$slot" \
        '.[] | select(.monitor==$mon and .name==$n) | .name' <<<"$WS_JSON")
  [[ -z "$tgt" ]] && tgt="$(ws_name_for_mid "$MID" "$slot")"
  hyprctl dispatch workspace "name:${tgt}" >/dev/null
  # If wrapped and ended up elsewhere, pin it to this monitor
  hyprctl dispatch moveworkspacetomonitor "name:${tgt}" "$MNAME" >/dev/null 2>&1 || true
}

if [[ "$DIR" == "down" ]]; then
  [[ -z "$CUR_SLOT" ]] && exit 0
  # previous existing
  prev=""
  for s in "${SLOTS[@]}"; do
    (( s < CUR_SLOT )) && prev="$s" || break
  done
  if [[ -n "$prev" ]]; then
    goto_slot "$prev"
    exit 0
  fi
  # wrap: at first → go to NEXT_ALLOWED (create if needed)
  goto_slot "$NEXT_ALLOWED"
  exit 0
fi

# ---- UP logic ----

# 1) If a next existing slot > current exists, go there
if [[ -n "$CUR_SLOT" ]]; then
  for s in "${SLOTS[@]}"; do
    if (( s > CUR_SLOT )); then
      goto_slot "$s"
      exit 0
    fi
  done
fi

# 2) No next existing:
#    - If we are sitting at NEXT_ALLOWED already → wrap to FIRST_EXIST
if [[ -n "$CUR_SLOT" ]] && (( CUR_SLOT == NEXT_ALLOWED )) && (( FIRST_EXIST > 0 )); then
  goto_slot "$FIRST_EXIST"
  exit 0
fi

#    - Else consider creating up to NEXT_ALLOWED (respect boundary)
if [[ -n "$CUR_SLOT" ]] && (( CUR_SLOT < NEXT_ALLOWED )); then
  goto_slot "$NEXT_ALLOWED"
  exit 0
fi

# Nothing to do
exit 0
