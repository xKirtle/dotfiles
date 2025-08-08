#!/bin/bash
# Usage: ws-cycle-smart.sh [gap|max] up|down
set -euo pipefail

ALLOC="${1:-max}"
if [[ "$ALLOC" == "gap" || "$ALLOC" == "max" ]]; then
    shift
else
    ALLOC="max"
fi
DIRECTION="${1:-up}"

command -v jq >/dev/null || { notify-send "Install 'jq' for ws-cycle"; exit 1; }

ACTIVE_MONITOR=$(hyprctl -j monitors | jq -r '.[] | select(.focused==true).name')
[[ -n "$ACTIVE_MONITOR" ]] || exit 0

ACTIVE_WS_JSON=$(hyprctl -j activeworkspace)
CURRENT_ID=$(jq -r '.id' <<<"$ACTIVE_WS_JSON")
CURRENT_NAME=$(jq -r '.name' <<<"$ACTIVE_WS_JSON")

mapfile -t WS_NAMES < <(hyprctl -j workspaces | jq -r --arg mon "$ACTIVE_MONITOR" '[.[] | select(.monitor==$mon) | select(.name|test("^[0-9]+$")) | .name] | map(tonumber) | sort | map(tostring) | .[]')

if [[ "$CURRENT_NAME" =~ ^[0-9]+$ && ! " ${WS_NAMES[*]} " =~ " $CURRENT_NAME " ]]; then
  WS_NAMES+=("$CURRENT_NAME")
  mapfile -t WS_NAMES < <(printf '%s\n' "${WS_NAMES[@]}" | sort -n)
fi

CUR_IDX=-1
if [[ "$CURRENT_NAME" =~ ^[0-9]+$ ]]; then
  for i in "${!WS_NAMES[@]}"; do
    [[ "${WS_NAMES[$i]}" == "$CURRENT_NAME" ]] && CUR_IDX=$i && break
  done
fi

clients_json=$(hyprctl -j clients)
CURRENT_TILE_COUNT=$(jq --argjson id "$CURRENT_ID" '[.[] | select(.workspace.id==$id)] | length' <<<"$clients_json")

next_free_gap() {
  local used i
  used=$(hyprctl -j workspaces | jq -r '.[] | select(.name|test("^[0-9]+$")) | .name' | sort -n | uniq)
  i=1; while :; do if ! grep -qx "$i" <<<"$used"; then echo "$i"; return; fi; i=$((i+1)); done
}
next_free_max() {
  hyprctl -j workspaces | jq -r '[.[] | select(.name|test("^[0-9]+$")) | .name | tonumber] | if length==0 then 1 else (max+1) end'
}

get_next_id() {
  if [[ "$ALLOC" == "gap" ]]; then
    next_free_gap
  else
    next_free_max
  fi
}

case "$DIRECTION" in
  up)
    [[ "$CURRENT_TILE_COUNT" -eq 0 ]] && exit 0
    if (( CUR_IDX >= 0 && CUR_IDX+1 < ${#WS_NAMES[@]} )); then
      hyprctl dispatch workspace "${WS_NAMES[$((CUR_IDX+1))]}"
    else
      hyprctl dispatch workspace "$(get_next_id)"
    fi
    ;;
  down)
    (( CUR_IDX <= 0 )) && exit 0
    hyprctl dispatch workspace "${WS_NAMES[$((CUR_IDX-1))]}"
    ;;
  *)
    echo "Usage: $0 [gap|max] up|down" >&2
    exit 1
    ;;
esac