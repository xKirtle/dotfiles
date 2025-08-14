#!/usr/bin/env bash
set -euo pipefail

# Requirements: jq, playerctl, playerctld
#   pacman -S jq playerctl
# Notes:
# - This script ensures only one instance runs (flock).
# - It will start hypridle when not inhibited, and stop ALL instances when inhibited.
# - Inhibition condition: (any MPRIS "Playing") OR (any Hyprland client fullscreen == true)

HYPRIDLE_BIN="${HYPRIDLE_BIN:-hypridle}"
CHECK_INTERVAL="${CHECK_INTERVAL:-1}"   # seconds for fullscreen polling
LOCKFILE="${LOCKFILE:-$XDG_RUNTIME_DIR/hypridle-inhibit.lock}"

# ---------------- helpers ----------------
log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

start_hypridle() {
  if ! pgrep -x hypridle >/dev/null; then
    log "starting hypridle"
    ${HYPRIDLE_BIN} & disown
  fi
}

stop_hypridle() {
  if pgrep -x hypridle >/dev/null; then
    log "stopping ALL hypridle instances"
    pkill -x hypridle || true
    # wait briefly for clean exit
    for _ in $(seq 1 10); do
      pgrep -x hypridle >/dev/null || break
      sleep 0.1
    done
  fi
}

is_fullscreen() {
  # true if any client is true fullscreen
  hyprctl clients -j 2>/dev/null | jq -e 'map(select(.fullscreen == true)) | length > 0' >/dev/null
}

any_media_playing_once() {
  # Any player reporting Playing via MPRIS (case/whitespace tolerant)
  playerctl -a status 2>/dev/null | grep -iq '^[[:space:]]*playing'
}

cleanup() {
  # leave hypridle running when the watchdog exits
  start_hypridle
}
trap cleanup EXIT INT TERM

# ---------------- single-instance guard ----------------
# Use a subshell to hold the flock for the duration of the script
exec 9>"$LOCKFILE"
if ! flock -n 9; then
  log "another hypridle-inhibit is already running. exiting."
  exit 0
fi

# ---------------- bootstrap ----------------
# Make sure playerctl aggregator is up (harmless if already running)
command -v playerctld >/dev/null && playerctld daemon >/dev/null 2>&1 || true

# Initial state
MEDIA_PLAYING=0
if any_media_playing_once; then MEDIA_PLAYING=1; fi

# Kick hypridle on so we start "uninhibited" unless a reason is active
start_hypridle

# ---------------- event listener (MPRIS) ----------------
# Follow MPRIS status changes and update MEDIA_PLAYING immediately.
# We recompute from scratch on each event to handle multiple players cleanly.
event_listener() {
  # --follow prints on changes; no output when idle
  playerctl -a --follow status 2>/dev/null | while IFS= read -r _; do
    if any_media_playing_once; then
      MEDIA_PLAYING=1
    else
      MEDIA_PLAYING=0
    fi
  done
}

# Launch listener in background
event_listener & LISTENER_PID=$!

# ---------------- main loop ----------------
log "watchdog started (interval=${CHECK_INTERVAL}s)"
while sleep "${CHECK_INTERVAL}"; do
  FULL=$([ "$(is_fullscreen && echo 1 || echo 0)" -eq 1 ] && echo 1 || echo 0)
  MEDIA=$([ "$(any_media_playing_once && echo 1 || echo 0)" -eq 1 ] && echo 1 || echo 0)

  # Optional: quick log while debugging
  # log "state fullscreen=${FULL} media=${MEDIA}"

  if [[ "$FULL" -eq 1 || "$MEDIA" -eq 1 ]]; then
    stop_hypridle
  else
    start_hypridle
  fi
done

