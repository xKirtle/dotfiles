#!/usr/bin/env bash
set -Eeuo pipefail

### --- Config ----------------------------------------------
WALLPAPER_DIR="${HOME}/Pictures/Wallpapers"
CACHE_DIR="${HOME}/.cache/wallpaper"
CURRENT_LINK="${CACHE_DIR}/current"              # symlink to current image
COLOR_STAMP_DIR="${CACHE_DIR}/colors"            # stamp files by image hash
LOG="${CACHE_DIR}/wallpaper.log"

# Tools
HYPRCTL="$(command -v hyprctl)"
HYPRPAPER="$(command -v hyprpaper)"
MATUGEN="$(command -v matugen || true)"
WALLUST="$(command -v wallust || true)"

# Themed services we manage
SERVICES=( "waybar" "swaync" "nm-applet" "swayosd" )

# Update SDDM background (requires sudoers entry, see note)
SDDM_BG_TARGET="/usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds/dynamic.jpg"
SDDM_CONF_SOURCE="${HOME}/.config/matugen/sddm.conf"
SDDM_CONF_TARGET="/usr/share/sddm/themes/sddm-astronaut-theme/Themes/custom.conf"

### -------------------------------------------------------------------------

mkdir -p "${CACHE_DIR}" "${COLOR_STAMP_DIR}"
: > "${LOG}" || true

log() { printf '[%(%F %T)T] %s\n' -1 "$*" | tee -a "${LOG}" >&2; }

usage() {
  cat <<EOF
Usage:
  wallpaper --init [--random] [--sddm]
  wallpaper /full/path/to/image.(jpg|png) [--sddm]
  wallpaper --random [--sddm]
  wallpaper --force-colors

Notes:
  --init         : pick the previously used wallpaper. Random if none is found.
  --random       : pick a random image from WALLPAPER_DIR.
  --sddm         : force SDDM copy even if disabled in config.
  --force-colors : re-run color generation for the current image.
EOF
}

# --- Helpers ---------------------------------------------------------------

sha_img() {
  # Stable identity by content, not path.
  sha256sum -- "$1" | awk '{print $1}'
}

ensure_symlink() {
  local img="$1"
  ln -sfn -- "$img" "$CURRENT_LINK"
}

# Recommended to create /etc/sudoers.d/wallpaper with:
# $USER ALL=(ALL) NOPASSWD: /usr/bin/cp * /usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds/dynamic.jpg, /usr/bin/cp * /usr/share/sddm/themes/sddm-astronaut-theme/Themes/custom.conf
update_sddm() {
  local img="$1" force="${2:-0}"
  [[ -z "${SDDM_BG_TARGET}" && "${force}" != "1" ]] && return 0
  [[ -z "${SDDM_BG_TARGET}" && "${force}" == "1" ]] && \
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
    # sudo install -d -m 0755 -- "$(dirname "${SDDM_CONF_TARGET}")"
    sudo cp -f -- "$src_conf" "$SDDM_CONF_TARGET"
    rm -f -- "$src_conf"
  fi
}

wait_for_hyprland() {
  # Wait up to 5s for Hyprland socket to accept commands
  for _ in {1..50}; do
    if ${HYPRCTL} -j monitors >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done
  log "Hyprland socket not ready after timeout; continuing anyway"
  return 1
}

ensure_hyprpaper_up() {
  wait_for_hyprland

  # Start hyprpaper if not running
  if ! pgrep -u "$USER" -x "$(basename "${HYPRPAPER}")" >/dev/null 2>&1; then
    log "Starting hyprpaper daemon"
    setsid -f "${HYPRPAPER}" >/dev/null 2>&1 < /dev/null
  fi

  # Wait up to 3s for hyprpaper IPC to accept commands
  for _ in {1..30}; do
    if ${HYPRCTL} hyprpaper listpreloaded >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done
  log "hyprpaper IPC not ready after timeout; continuing anyway"
}

set_hyprpaper_all() {
  local img="$1"
  ensure_hyprpaper_up

  # Clear any pinned state
  hyprctl hyprpaper unload all >/dev/null 2>&1 || true

  # Preload with a small backoff
  hyprctl hyprpaper preload "$img" >/dev/null 2>&1 || true
  sleep 0.05
  hyprctl hyprpaper preload "$img" >/dev/null 2>&1 || true

  # Enumerate monitors; avoid "all," path
  local monitors
  monitors="$(hyprctl -j monitors | jq -r '.[].name')" || monitors=""
  if [[ -z "$monitors" ]]; then
    log "No monitors yet; retrying once with shorthand"
    hyprctl hyprpaper wallpaper "all,${img}" >/dev/null 2>&1 || true
    return 0
  fi

  while read -r m; do
    [[ -z "$m" ]] && continue

    # Try up to 5 times per monitor: preload+apply until it sticks
    for _ in {1..5}; do
      if hyprctl hyprpaper wallpaper "${m},${img}" >/dev/null 2>&1; then
        break
      fi
      sleep 0.12
      hyprctl hyprpaper preload "$img" >/dev/null 2>&1 || true
    done
  done <<< "$monitors"
}

colors_needed() {
  # Re-run colors unless the last processed path matches this exact file (after realpath).
  local img_real; img_real="$(readlink -f -- "$1")"
  local last_file="${CACHE_DIR}/last-colored"

  # If we've never processed anything, we need colors.
  [[ ! -f "$last_file" ]] && return 0

  # Compare normalized paths.
  local last_real
  last_real="$(readlink -f -- "$(cat "$last_file" 2>/dev/null || echo "")" 2>/dev/null || true)"

  # Need colors if last != current.
  [[ "$last_real" != "$img_real" ]]
}

mark_colors_done() {
  local img_real; img_real="$(readlink -f -- "$1")"
  printf '%s\n' "$img_real" > "${CACHE_DIR}/last-colored"
}

run_matugen() {
  local img="$1"
  [[ -z "${MATUGEN}" ]] && { log "matugen not found; skipping"; return 0; }
  log "Running matugen…"
  "${MATUGEN}" image "$img" --config "${HOME}/.config/matugen/config.toml"
}

run_wallust() {
  local img="$1"
  [[ -z "${WALLUST}" ]] && { log "wallust not found; skipping"; return 0; }
  log "Running wallust…"
  "${WALLUST}" run "$img" --config-dir "${HOME}/.config/wallust"
}

is_running() {
  pgrep -u "$USER" -x "$1" >/dev/null 2>&1
}

# --- helpers for robust background starts ----------------------------------
run_bg() {
  # Start command fully detached, ignore all stdio, never block this script
  setsid -f "$@" >/dev/null 2>&1 < /dev/null
}

try_timeout() {
  # try_timeout 2s cmd args...
  local t="$1"; shift
  command -v timeout >/dev/null 2>&1 || { "$@"; return $?; }
  timeout --preserve-status "$t" "$@"
}

is_running() { 
  pgrep -u "$USER" -x "$1" >/dev/null 2>&1; 
}

start_or_reload_services() {
  echo "Reloading services..."

  # waybar: reload if running, else start
  if is_running waybar; then
    pkill -USR2 waybar || true
  else
    run_bg waybar
  fi

  echo "waybar has been (re)started"

  # swaync: prefer client (fast), but never let it hang.
  if is_running swaync; then
    # Try reload+restart via client, but cap it with a short timeout.
    if ! try_timeout 2s swaync-client -rs; then
      # Hard restart if client is wedged.
      pkill -TERM swaync || true
      sleep 0.2
      run_bg swaync
    fi
  else
    # Daemon not running — just start detached.
    run_bg swaync
  fi

  echo "swaync has been (re)started"

  # nm-applet: ensure running (themes rarely affect it, keep simple)
  is_running nm-applet || run_bg nm-applet --indicator

  echo "nm-applet has been (re)started"

  # swayosd: ensure running; reload if client is available
  if is_running swayosd; then
    command -v swayosd-client >/dev/null 2>&1 && \
      try_timeout 2s swayosd-client --reload || true
  else
    run_bg swayosd
  fi

  echo "swayosd has been (re)started"
}

process_image() {
  local img="$1" force_sddm="${2:-0}"

  if [[ ! -f "$img" ]]; then
    log "Image not found: $img"; exit 2
  fi

  ensure_symlink "$img"
  set_hyprpaper_all "$img"

  if [[ "$FORCE_COLORS" -eq 1 ]] || colors_needed "$img"; then
    log "Colors need update for image."
    run_matugen "$img"
    run_wallust "$img"
    mark_colors_done "$img"
    start_or_reload_services
  else
    log "Colors already up-to-date. Only reloading UI bits."
    # light-weight reloads to reflect style tweaks if any
    start_or_reload_services
  fi

  update_sddm "$img" "$force_sddm"
}

pick_random_image() {
  # Build a list of images under WALLPAPER_DIR, excluding the current one.
  local current=""
  if [[ -L "${CURRENT_LINK}" || -f "${CURRENT_LINK}" ]]; then
    current="$(readlink -f -- "${CURRENT_LINK}" 2>/dev/null || true)"
  fi

  # Collect all images (null-delimited to handle spaces/newlines)
  local -a all=()
  while IFS= read -r -d '' f; do
    all+=("$f")
  done < <(find "$WALLPAPER_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0)

  # If nothing found, bail
  if ((${#all[@]} == 0)); then
    log "No images found in ${WALLPAPER_DIR}"
    return 1
  fi

  # Filter out the current image (by real path)
  local -a cand=()
  for f in "${all[@]}"; do
    local rf
    rf="$(readlink -f -- "$f")"
    if [[ -n "$current" && "$rf" == "$current" ]]; then
      continue
    fi
    cand+=("$f")
  done

  # If exclusion emptied the set, fall back to the only image
  if ((${#cand[@]} == 0)); then
    printf '%s' "${all[0]}"
    return 0
  fi

  # Pick one at random from candidates (null-safe)
  printf '%s\0' "${cand[@]}" | shuf -z -n1 | xargs -0 -I{} printf '%s' "{}"
}

# --- CLI parsing -----------------------------------------------------------
IMG=""
INIT=0
RANDOM_PICK=0
FORCE_SDDM=0
FORCE_COLORS=0

if [[ $# -eq 0 ]]; then usage; exit 1; fi
while [[ $# -gt 0 ]]; do
  case "$1" in
    --init) INIT=1 ;;
    --random) RANDOM_PICK=1 ;;
    --sddm) FORCE_SDDM=1 ;;
    --force-colors) FORCE_COLORS=1 ;;
    -h|--help) usage; exit 0 ;;
    *) if [[ -z "${IMG}" ]]; then IMG="$1"; else echo "Unexpected arg: $1" >&2; exit 1; fi ;;
  esac
  shift
done

# --- Main ------------------------------------------------------------------

if [[ "${INIT}" -eq 1 ]]; then
  # On init: if we have a current symlink, reuse it, else pick random (or fail if no random requested)
  if [[ -L "${CURRENT_LINK}" && -f "${CURRENT_LINK}" ]]; then
    IMG="$(readlink -f -- "${CURRENT_LINK}")"
    log "--init: using existing ${IMG}"
  elif [[ "${RANDOM_PICK}" -eq 1 ]]; then
    IMG="$(pick_random_image)"; log "--init: picked random ${IMG}"
  elif [[ -n "${IMG}" ]]; then
    log "--init: using provided ${IMG}"
  else
    log "--init: no current symlink and no image given. Try --random or provide a file."
    exit 1
  fi
  process_image "$IMG" "$FORCE_SDDM"
  exit 0
fi

if [[ "${RANDOM_PICK}" -eq 1 ]]; then
  IMG="$(pick_random_image)"; log "Picked random ${IMG}"
fi

if [[ -z "${IMG}" ]]; then
  log "No image provided. See --help."
  exit 1
fi

process_image "$IMG" "$FORCE_SDDM"
