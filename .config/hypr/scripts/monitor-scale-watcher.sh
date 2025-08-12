#!/usr/bin/env bash
set -euo pipefail

########## CONFIG ##########
MAIN_DESC='LG Electronics LG ULTRAGEAR+ 411NTTQ06481'
SIDE_DESC='LG Electronics LG ULTRAGEAR 310NTCZ6H379'

# What "defines" each hardware mode, by presence in availableModes
FOURK_W=3840
FOURK_H=2160
FOURK_MIN_HZ=230     # 4K bucket appears if 4K@>=230Hz is advertised

FHD_W=1920
FHD_H=1080
FHD_MIN_HZ=470       # 1080p high-speed bucket if 1080p@>=470Hz is advertised

# MAIN per-mode placement/scale
MAIN_PLACE_4K="0x0"
MAIN_SCALE_4K="1.25"

MAIN_PLACE_1080="0x300"
MAIN_SCALE_1080="1.0"

# SIDE fixed
SIDE_RES="3440x1440@160"
SIDE_PLACE="-1440x-1560"
SIDE_SCALE="1"
SIDE_TRANSFORM="1"

# Timings / retries
POLL_INTERVAL="1"
SETTLE_AFTER_APPLY="0.4"
RETRIES=3
RETRY_SLEEP="0.4"
######## END CONFIG ########

log() { printf '[hypr-smart-align] %s\n' "$*"; }

wait_for_hypr() { until hyprctl -j monitors >/dev/null 2>&1; do sleep 0.5; done; }

apply_side() {
  hyprctl keyword monitor "desc:${SIDE_DESC},${SIDE_RES},${SIDE_PLACE},${SIDE_SCALE},transform,${SIDE_TRANSFORM}" >/dev/null
}

json_all() { hyprctl -j monitors all; }
json_now() { hyprctl -j monitors; }

# Return 1 if a mode (W,H,RR>=min) exists in availableModes
modes_has() {
  local w="$1" h="$2" minrr="$3"
  json_all | jq -e --arg d "$MAIN_DESC" --argjson W "$w" --argjson H "$h" --argjson MIN "$minrr" '
    .[] | select(.description==$d) |
    (.availableModes // []) as $m |
    any($m[]?; capture("(?<W>\\d+)x(?<H>\\d+)@(?<R>[0-9.]+)Hz") as $c
      | ($c.W|tonumber)==$W and ($c.H|tonumber)==$H and ($c.R|tonumber)>=$MIN)
  ' >/dev/null
}

# Pick the highest refresh for the given W×H with RR>=min
pick_best_mode() {
  local w="$1" h="$2" minrr="$3"
  json_all | jq -r --arg d "$MAIN_DESC" --argjson W "$w" --argjson H "$h" --argjson MIN "$minrr" '
    .[] | select(.description==$d) |
    (.availableModes // []) as $m |
    [ $m[]? | capture("(?<W>\\d+)x(?<H>\\d+)@(?<R>[0-9.]+)Hz")
      | select((.W|tonumber)==$W and (.H|tonumber)==$H and (.R|tonumber)>=$MIN)
      | {r: (.R|tonumber), s: "\(.W)x\(.H)@\(.R)"} ] |
    sort_by(-.r) | (.[0].s // empty)
  '
}

# What are we currently at?
bucket_now() {
  json_now | jq -r --arg d "$MAIN_DESC" '
    .[] | select(.description==$d) | {w:.width,h:.height} |
    if .w=='"$FOURK_W"' and .h=='"$FOURK_H"' then "4k"
    elif .w=='"$FHD_W"' and .h=='"$FHD_H"' then "1080"
    else "other" end
  '
}

apply_main() { # args: MODESTR PLACE SCALE
  hyprctl keyword monitor "desc:${MAIN_DESC},$1,$2,$3" >/dev/null
}

# Force re-probe if needed: disable -> enable with target mode
nudge_output() { # args: MODESTR PLACE SCALE
  hyprctl keyword monitor "desc:${MAIN_DESC},disable" >/dev/null
  sleep 0.2
  hyprctl keyword monitor "desc:${MAIN_DESC},$1,$2,$3" >/dev/null
}

ensure_bucket() { # args: targetBucket
  local target="$1" best place scale
  if [[ "$target" == "4k" ]]; then
    best=$(pick_best_mode "$FOURK_W" "$FOURK_H" "$FOURK_MIN_HZ")
    [[ -z "$best" ]] && best="preferred"
    place="$MAIN_PLACE_4K"; scale="$MAIN_SCALE_4K"
  else
    best=$(pick_best_mode "$FHD_W" "$FHD_H" "$FHD_MIN_HZ")
    [[ -z "$best" ]] && best="${FHD_W}x${FHD_H}@${FHD_MIN_HZ}"
    place="$MAIN_PLACE_1080"; scale="$MAIN_SCALE_1080"
  fi

  for ((i=1;i<=RETRIES;i++)); do
    apply_main "$best" "$place" "$scale"
    sleep "$SETTLE_AFTER_APPLY"
    [[ "$(bucket_now)" == "$target" ]] && { log "Applied $target: $best $place scale=$scale"; return 0; }
    # try a nudge if plain apply didn't stick
    nudge_output "$best" "$place" "$scale"
    sleep "$RETRY_SLEEP"
    [[ "$(bucket_now)" == "$target" ]] && { log "Nudged to $target: $best"; return 0; }
  done
  log "WARN: failed to switch to $target after $RETRIES tries"
  return 1
}

# --- main ---
wait_for_hypr
apply_side

last_applied=""

while sleep "$POLL_INTERVAL"; do
  # Decide desired bucket based on what modes are *advertised right now*
  if modes_has "$FOURK_W" "$FOURK_H" "$FOURK_MIN_HZ"; then
    desired="4k"
  elif modes_has "$FHD_W" "$FHD_H" "$FHD_MIN_HZ"; then
    desired="1080"
  else
    desired="unknown"
  fi

  [[ "$desired" == "unknown" ]] && continue
  [[ "$desired" == "$last_applied" && "$(bucket_now)" == "$desired" ]] && continue

  ensure_bucket "$desired" || true
  last_applied="$desired"
done