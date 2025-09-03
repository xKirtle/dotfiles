#!/usr/bin/env bash
set -euo pipefail

# Requirements: jq, playerctl, playerctld
#   pacman -S jq playerctl
# Notes:
# - This script can run as a daemon (watchdog) or be called by Waybar to toggle/check status.
# - Manual override file controls enable/disable globally.
# - Effective state = (override == "enabled") AND (not (media playing OR fullscreen)).

HYPRIDLE_BIN="${HYPRIDLE_BIN:-hypridle}"
CHECK_INTERVAL="${CHECK_INTERVAL:-1}"   # seconds for fullscreen polling
LOCKFILE="${LOCKFILE:-${XDG_RUNTIME_DIR:-/tmp}/hypridle-inhibit.lock}"
OVERRIDE_FILE="${OVERRIDE_FILE:-${XDG_RUNTIME_DIR:-/tmp}/hypridle.override}"  # "enabled" or "disabled"

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

# ---------------- manual override helpers ----------------
get_override() {
  if [[ -f "$OVERRIDE_FILE" ]]; then
    tr -d '[:space:]' < "$OVERRIDE_FILE"
  else
    echo "enabled"
  fi
}

set_override() {
  printf '%s\n' "$1" > "$OVERRIDE_FILE"
}

toggle_override() {
  if [[ "$(get_override)" == "enabled" ]]; then
    set_override "disabled"
    notify-send "Hypridle" "Manually disabled"
  else
    set_override "enabled"
    notify-send "Hypridle" "Manually enabled"
  fi
}

# ---------------- hypridle control ----------------
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
    for _ in $(seq 1 10); do
      pgrep -x hypridle >/dev/null || break
      sleep 0.1
    done
  fi
}

# ---------------- inhibition predicates ----------------
is_fullscreen() {
  hyprctl clients -j 2>/dev/null | jq -e 'map(select(.fullscreen == true)) | length > 0' >/dev/null
}

any_media_playing_once() {
  playerctl -a status 2>/dev/null | grep -iq '^[[:space:]]*playing'
}

# ---------------- status for Waybar ----------------
print_status_json() {
  local override media fs state tooltip pct

  override="$(get_override)"
  any_media_playing_once && media=1 || media=0
  is_fullscreen && fs=1 || fs=0

  if [[ "$override" == "disabled" ]]; then
    state="disabled";
    tooltip="Hypridle manually disabled";
    pct=0
  else
    if [[ $media -eq 1 || $fs -eq 1 ]]; then
      state="inhibited";
      tooltip="Temporarily inhibited (media/fullscreen)";
      pct=50
    else
      state="active";
      tooltip="Hypridle active";
      pct=100
    fi
  fi

  # class is handy for CSS (optional)
  printf '{"text":"","class":"%s","percentage":%d,"tooltip":"%s"}\n' \
    "$state" "$pct" "$tooltip"
}

# ---------------- daemon (watchdog) ----------------
daemon() {
  # single instance guard
  exec 9>"$LOCKFILE"
  if ! flock -n 9; then
    log "another hypridle-inhibit is already running. exiting."
    exit 0
  fi

  # Kick playerctld aggregator (harmless if already running)
  command -v playerctld >/dev/null && playerctld daemon >/dev/null 2>&1 || true

  # Start uninhibited by default unless override disables it
  [[ "$(get_override)" == "enabled" ]] && start_hypridle || stop_hypridle

  # Event listener to update MEDIA state quickly
  any_media_playing_once && MEDIA_PLAYING=1 || MEDIA_PLAYING=0
  event_listener & LISTENER_PID=$!

  cleanup() {
    # leave hypridle running if override says enabled; otherwise ensure stopped
    if [[ "$(get_override)" == "enabled" ]]; then
      start_hypridle
    else
      stop_hypridle
    fi
    [[ -n "${LISTENER_PID:-}" ]] && kill "$LISTENER_PID" >/dev/null 2>&1 || true
  }
  trap cleanup EXIT INT TERM

  log "watchdog started (interval=${CHECK_INTERVAL}s)"
  while sleep "${CHECK_INTERVAL}"; do
    local override media fs
    override="$(get_override)"
    any_media_playing_once && media=1 || media=0
    is_fullscreen && fs=1 || fs=0

    if [[ "$override" == "disabled" ]]; then
      # manual disable forces hypridle off
      stop_hypridle
      continue
    fi

    # normal logic: stop when transient reasons exist; run otherwise
    if [[ $media -eq 1 || $fs -eq 1 ]]; then
      stop_hypridle
    else
      start_hypridle
    fi
  done
}

event_listener() {
  playerctl -a --follow status 2>/dev/null | while IFS= read -r _; do :; done
}

# ---------------- CLI ----------------
case "${1:-}" in
  --daemon)   daemon ;;
  --toggle)   toggle_override ;;
  --enable)   set_override "enabled" ;;
  --disable)  set_override "disabled" ;;
  --status)   print_status_json ;;
  ""|--help|-h)
    cat <<EOF
Usage: $(basename "$0") [--daemon|--toggle|--enable|--disable|--status]
  --daemon   Run the watchdog loop (start from Hyprland or systemd --user)
  --toggle   Toggle manual override (enabled <-> disabled)
  --enable   Manually enable hypridle control (watchdog rules apply)
  --disable  Manually disable hypridle entirely
  --status   Emit JSON for Waybar (icon + tooltip)
EOF
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 2
    ;;
esac
