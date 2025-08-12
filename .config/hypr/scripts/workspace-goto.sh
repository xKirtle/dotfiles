#!/usr/bin/env bash
# workspace-goto.sh <1-9>
# Behavior:
# - If N exists locally → jump.
# - If N doesn't exist:
#   * If LAST_OCC == 0 (nothing occupied yet):
#       - TARGET = MAX_EXIST+1
#       - If N >= TARGET:
#           • if already on TARGET → no-op
#           • else → go to TARGET (creates it if needed)
#       - else → no-op
#   * If LAST_OCC > 0:
#       - BOUND = LAST_OCC+1
#       - If N > BOUND:
#           • if already on/above BOUND → no-op
#           • else → go to BOUND
#       - If N == BOUND:
#           • if already on BOUND → no-op
#           • else → go to BOUND (creates if needed)
#       - If N < BOUND:
#           • if N exists (already handled) else → no-op

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/workspace-lib.sh"

N="${1:-}"; [[ "$N" =~ ^[1-9]$ ]] || { echo "need 1..9"; exit 1; }
command -v jq >/dev/null || { notify-send "Install jq"; exit 1; }

MONS=$(hyprctl -j monitors)
MID=$(jq -r '.[] | select(.focused==true).id' <<<"$MONS")
MNAME=$(jq -r '.[] | select(.focused==true).name' <<<"$MONS")
[[ "$MID" != "null" && -n "$MNAME" ]] || exit 0

WS_JSON=$(hyprctl -j workspaces)

# Current local slot (numeric-on-this-monitor OR wrapped-for-this-MID)
CUR_SLOT=""
CURNAME=$(hyprctl -j activeworkspace | jq -r '.name')
if [[ "$CURNAME" =~ ^[0-9]+$ ]]; then
  if jq -e --arg mon "$MNAME" --arg n "$CURNAME" 'any(.[]; .monitor==$mon and .name==$n)' >/dev/null <<<"$WS_JSON"; then
    CUR_SLOT="$CURNAME"
  fi
elif ws_is_for_mid "$MID" "$CURNAME"; then
  CUR_SLOT="$(printf '%s' "$CURNAME" | ws_strip_invis)"
fi
[[ "$CUR_SLOT" == "$N" ]] && exit 0  # already there → no-op

goto_slot () {
  local slot="$1" tgt
  tgt=$(jq -r --arg mon "$MNAME" --arg n "$slot" \
        '.[] | select(.monitor==$mon and .name==$n) | .name' <<<"$WS_JSON")
  [[ -z "$tgt" ]] && tgt="$(ws_name_for_mid "$MID" "$slot")"
  # If decision ends up on current, no-op (prevents bounce)
  [[ "$slot" == "$CUR_SLOT" ]] && exit 0
  hyprctl dispatch workspace "name:${tgt}" >/dev/null
  hyprctl dispatch moveworkspacetomonitor "name:${tgt}" "$MNAME" >/dev/null 2>&1 || true
}

# 1) Existing numeric N on this monitor → jump
CAND_NUM=$(jq -r --arg mon "$MNAME" --arg n "$N" \
  '.[] | select(.monitor==$mon and .name==$n) | .name' <<<"$WS_JSON")
if [[ -n "$CAND_NUM" ]]; then
  hyprctl dispatch workspace "$CAND_NUM" >/dev/null
  exit 0
fi

# 2) Existing wrapped N anywhere → jump + pin
TGT_WRAPPED="$(ws_name_for_mid "$MID" "$N")"
CAND_WRAP=$(jq -r --arg w "$TGT_WRAPPED" '.[] | select(.name==$w) | .name' <<<"$WS_JSON")
if [[ -n "$CAND_WRAP" ]]; then
  hyprctl dispatch workspace "name:${CAND_WRAP}" >/dev/null
  hyprctl dispatch moveworkspacetomonitor "name:${CAND_WRAP}" "$MNAME" >/dev/null 2>&1 || true
  exit 0
fi

# 3) N doesn't exist → compute MAX_EXIST and LAST_OCC
readarray -t SLOTS_NUM < <(jq -r --arg mon "$MNAME" '.[] | select(.monitor==$mon) | .name' <<<"$WS_JSON" | grep -E '^[0-9]+$' || true)
readarray -t SLOTS_WRP < <(jq -r '.[].name' <<<"$WS_JSON" | while read -r n; do
  ws_is_for_mid "$MID" "$n" && printf '%s\n' "$n" | ws_strip_invis || true
done)
readarray -t SLOTS < <(printf "%s\n" "${SLOTS_NUM[@]}" "${SLOTS_WRP[@]}" | grep -E '^[0-9]+$' | sort -n | uniq)
MAX_EXIST=0; ((${#SLOTS[@]})) && MAX_EXIST="${SLOTS[-1]}"

CL_JSON=$(hyprctl -j clients)
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

if (( LAST_OCC == 0 )); then
  # nothing occupied yet → single-step to TARGET = MAX_EXIST+1, then stop there
  TARGET=$((MAX_EXIST + 1))
  if (( N >= TARGET )); then
    if [[ "$CUR_SLOT" == "$TARGET" ]]; then
      exit 0   # already at boundary → stop (no bounce, no walking)
    fi
    goto_slot "$TARGET"
  fi
  exit 0
fi

# Some slots occupied → boundary B = LAST_OCC+1
B=$((LAST_OCC + 1))
if (( N > B )); then
  # clamp to boundary once; if already at/above, stop
  if [[ -n "$CUR_SLOT" ]] && (( CUR_SLOT >= B )); then
    exit 0
  fi
  goto_slot "$B"
  exit 0
fi

if (( N == B )); then
  # go to boundary (create if needed), unless already there
  [[ "$CUR_SLOT" == "$B" ]] && exit 0
  goto_slot "$B"
  exit 0
fi

# N < B: if it existed we'd have jumped earlier; otherwise do nothing
exit 0
