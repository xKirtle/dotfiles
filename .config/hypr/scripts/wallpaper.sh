#!/usr/bin/env bash
set -euo pipefail

# ── user config ───────────────────────────────────────────────────────────────
DEFAULT_WP="${DEFAULT_WP:-/usr/share/wallpapers/cachyos-wallpapers/Skyscraper.png}"
HCONF="${HCONF:-$HOME/.config/hypr/hyprpaper.conf}"
WPF_CACHE="${WPF_CACHE:-$HOME/.cache/hyprpaper.fingerprint}"
WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"

# SDDM targets (override as needed; leave empty to disable unless --sddm is passed)
SDDM_BG_TARGET="${SDDM_BG_TARGET:-/usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds/dynamic.jpg}"
SDDM_CONF_TARGET="${SDDM_CONF_TARGET:-/usr/share/sddm/themes/sddm-astronaut-theme/Themes/custom.conf}"

# ── binaries ─────────────────────────────────────────────────────────────────
HYPRCTL="$(command -v hyprctl)"
HYPRPAPER="$(command -v hyprpaper || true)"
MATUGEN="$(command -v matugen || true)"
WALLUST="$(command -v wallust || true)"
GDBUS="$(command -v gdbus || true)"
WAYBAR="$(command -v waybar || true)"
SWAYNC="$(command -v swaync || true)"
SWAYNC_CLIENT="$(command -v swaync-client || true)"

# ── helpers ──────────────────────────────────────────────────────────────────
log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

pick_random_wallpaper() {
  local dir="$1"
  [ -d "$dir" ] || { log "Wallpaper dir not found: $dir"; return 1; }
  mapfile -t files < <(find "$dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \))
  [ "${#files[@]}" -gt 0 ] || { log "No images in $dir"; return 1; }
  printf '%s\n' "$(printf '%s\n' "${files[@]}" | shuf -n1)"
}

ensure_hyprpaper() {
  pgrep -x hyprpaper >/dev/null && return 0
  if [ -n "$HYPRPAPER" ]; then
    log "Starting hyprpaper…"
    hyprpaper & disown
    sleep 0.1
  else
    log "hyprpaper not found; skipping."
  fi
}

set_wallpaper_all() {
  local wp="$1"
  [ -x "$HYPRCTL" ] || { log "hyprctl not found."; return 1; }
  log "Setting wallpaper to: $wp"
  "$HYPRCTL" hyprpaper preload "$wp" || true
  "$HYPRCTL" hyprpaper wallpaper ",$wp" || true
  [ -n "${WPF_CACHE:-}" ] && printf '%s\n' "$wp" >"$WPF_CACHE" || true
}

# ── themers (your exact syntax) ──────────────────────────────────────────────
run_matugen() {
  local img="$1"
  [[ -z "${MATUGEN}" ]] && { log "matugen not found; skipping"; return 0; }
  log "Running matugen…"
  "${MATUGEN}" image "$img" --config "${HOME}/.config/matugen/config.toml" || true
}

run_wallust() {
  local img="$1"
  [[ -z "${WALLUST}" ]] && { log "wallust not found; skipping"; return 0; }
  log "Running wallust…"
  "${WALLUST}" run "$img" --config-dir "${HOME}/.config/wallust" || true
}

run_themers() {
  local img="$1"
  run_matugen "$img"
  run_wallust "$img"
}

start_or_reload_swaync() {
  if pgrep -x swaync >/dev/null; then
    [ -n "$SWAYNC_CLIENT" ] && "$SWAYNC_CLIENT" -rs >/dev/null 2>&1 || true
  else
    if [ -n "$SWAYNC" ]; then
      log "Starting swaync…"
      swaync & disown
      sleep 0.05
    fi
  fi
}

wait_for_notifications_bus() {
  [ -n "$GDBUS" ] || return 0
  for _ in $(seq 1 50); do
    $GDBUS call --session \
      --dest org.freedesktop.DBus \
      --object-path /org/freedesktop/DBus \
      --method org.freedesktop.DBus.ListNames \
      | grep -q "'org.freedesktop.Notifications'" && return 0
    sleep 0.1
  done
  log "Timed out waiting for org.freedesktop.Notifications (continuing)."
  return 1
}

start_or_reload_waybar() {
  if pgrep -x waybar >/dev/null; then
    pkill -SIGUSR2 waybar || true
  else
    if [ -n "$WAYBAR" ]; then
      log "Starting waybar…"
      waybar & disown
    fi
  fi
}

# ── SDDM (your original behavior) ────────────────────────────────────────────
update_sddm() {
  local img="$1" force="${2:-0}"
  # If target is unset and not forced, do nothing
  [[ -z "${SDDM_BG_TARGET:-}" && "${force}" != "1" ]] && return 0
  # If unset but forced, just log that we're forcing anyway
  [[ -z "${SDDM_BG_TARGET:-}" && "${force}" == "1" ]] && \
    log "SDDM disabled in config but forced by --sddm"

  if [[ "${force}" == "1" ]]; then
    log "Updating SDDM background -> ${SDDM_BG_TARGET}"
    sudo cp -f -- "$img" "$SDDM_BG_TARGET"

    local src_conf
    src_conf="$(realpath -e "${HOME}/.config/matugen/sddm.conf")" || {
      log "Matugen SDDM config not found."
      return 1
    }

    log "Updating SDDM theme config -> ${SDDM_CONF_TARGET}"
    # If you ever need to ensure the directory exists:
    # sudo install -d -m 0755 -- "$(dirname "${SDDM_CONF_TARGET}")"
    sudo cp -f -- "$src_conf" "$SDDM_CONF_TARGET"
    rm -f -- "$src_conf"
  fi
}

# ── args ─────────────────────────────────────────────────────────────────────
RANDOM_PICK=0
FORCE_SDDM=0
FILE_ARG=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [--random] [--file /path/to/image] [--sddm]
  --random        Pick a random image from \$WALLPAPER_DIR ($WALLPAPER_DIR)
  --file PATH     Use a specific file as wallpaper
  --sddm          Force updating SDDM background + theme config from matugen
EOF
}

while (( $# )); do
  case "$1" in
    --random) RANDOM_PICK=1; shift ;;
    --file)   FILE_ARG="${2:-}"; shift 2 ;;
    --sddm)   FORCE_SDDM=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) log "Unknown argument: $1"; usage; exit 2 ;;
  esac
done

# ── choose wallpaper ──────────────────────────────────────────────────────────
WP=""
if [ -n "$FILE_ARG" ]; then
  WP="$FILE_ARG"
elif [ "$RANDOM_PICK" = "1" ]; then
  WP="$(pick_random_wallpaper "$WALLPAPER_DIR")"
else
  WP="$DEFAULT_WP"
fi

[ -f "$WP" ] || { log "Chosen wallpaper does not exist: $WP"; exit 1; }
log "Picked wallpaper: $WP"

# ── sequence to avoid swaync/waybar race ──────────────────────────────────────
ensure_hyprpaper
set_wallpaper_all "$WP"

run_themers "$WP"

start_or_reload_swaync
wait_for_notifications_bus || true
start_or_reload_waybar

update_sddm "$WP" "$FORCE_SDDM"

log "Done."
