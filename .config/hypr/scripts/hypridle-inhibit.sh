#!/usr/bin/env bash
set -euo pipefail

# Requirements: jq, playerctl
# pacman -S jq playerctl

HYPRIDLE_BIN="${HYPRIDLE_BIN:-hypridle}"
CHECK_INTERVAL="${CHECK_INTERVAL:-1}"   # seconds

hypridle_pid=""

start_hypridle() {
  if [[ -z "${hypridle_pid}" ]] || ! kill -0 "${hypridle_pid}" 2>/dev/null; then
    echo "[hypridle-inhibit] starting hypridle"
    ${HYPRIDLE_BIN} &
    hypridle_pid=$!
  fi
}

stop_hypridle() {
  if [[ -n "${hypridle_pid}" ]] && kill -0 "${hypridle_pid}" 2>/dev/null; then
    echo "[hypridle-inhibit] stopping hypridle"
    kill "${hypridle_pid}" || true
    wait "${hypridle_pid}" 2>/dev/null || true
    hypridle_pid=""
  fi
}

is_fullscreen() {
  hyprctl clients -j 2>/dev/null | jq -e 'map(select(.fullscreen == true)) | length > 0' >/dev/null
}

is_media_playing() {
  # Any player reporting Playing via MPRIS
  playerctl -a status 2>/dev/null | grep -q '^Playing$'
}

should_inhibit() {
  is_fullscreen || is_media_playing
}

cleanup() {
  # Leave hypridle running on exit (optional, comment out if you prefer it stopped)
  start_hypridle
}
trap cleanup EXIT INT TERM

# Ensure playerctl aggregator is up (harmless if already running)
command -v playerctld >/dev/null && playerctld daemon >/dev/null 2>&1 || true

# Main loop
start_hypridle
while sleep "${CHECK_INTERVAL}"; do
  if should_inhibit; then
    stop_hypridle
  else
    start_hypridle
  fi
done
