#!/usr/bin/env bash
set -euo pipefail

# Paths
WPF_FILE="${WPF_FILE:-$HOME/.cache/current_wallpaper}"          # “current” image
THEME_FILE="${THEME_FILE:-$HOME/.cache/current_wallpaper_theme}" # last image used to generate theme

# Binaries + configs (override via env if needed)
MATUGEN="${MATUGEN:-matugen}"
WALLUST="${WALLUST:-wallust}"
MATUGEN_CFG="${MATUGEN_CFG:-$HOME/.config/matugen/config.toml}"
WALLUST_CFG="${WALLUST_CFG:-$HOME/.config/wallust}"

# Services to (re)load
WAYBAR_CMD="${WAYBAR_CMD:-waybar}"
SWAYNC_CMD="${SWAYNC_CMD:-swaync}"
NM_APPLET_CMD="${NM_APPLET_CMD:-nm-applet --indicator}"
SWAYOSD_CMD="${SWAYOSD_CMD:-swayosd-server}"

mkdir -p -- "$(dirname "$WPF_FILE")" "$(dirname "$THEME_FILE")"

# Resolve current image (from cache, or optional $1 override)
resolve_img() {
  local img="${1:-}"
  if [[ -z "$img" && -f "$WPF_FILE" ]]; then
    img="$(awk 'NF{print; exit}' "$WPF_FILE" 2>/dev/null || true)"
  fi
  [[ -n "$img" ]] && { realpath -m -- "$img" 2>/dev/null || printf '%s\n' "$img"; }
}

IMG="$(resolve_img "${1:-}")"
if [[ -z "$IMG" ]]; then
  echo "[theme-reload] No cached wallpaper in $WPF_FILE; nothing to do."
  # Still try to ensure panels are running
  NEED_REGEN=0
else
  PREV="$( [[ -f "$THEME_FILE" ]] && awk 'NF{print; exit}' "$THEME_FILE" || echo "" )"
  if [[ "$IMG" != "$PREV" ]]; then
    NEED_REGEN=1
    echo "[theme-reload] Theme out of date → regenerating for: $IMG"
    if command -v "$MATUGEN" >/dev/null 2>&1; then
      "$MATUGEN" image "$IMG" --config "$MATUGEN_CFG" || echo "[theme-reload] matugen failed (non-fatal)"
    else
      echo "[theme-reload] matugen not found; skipping"
    fi
    if command -v "$WALLUST" >/dev/null 2>&1; then
      "$WALLUST" run "$IMG" --config-dir "$WALLUST_CFG" || echo "[theme-reload] wallust failed (non-fatal)"
    else
      echo "[theme-reload] wallust not found; skipping"
    fi
    printf '%s\n' "$IMG" > "$THEME_FILE"
  else
    NEED_REGEN=0
    echo "[theme-reload] Theme already up-to-date for: $IMG → skipping generators"
  fi
fi

# --- Reload / (re)start panels & daemons ---

# Waybar: reload if running; otherwise start
if pgrep -x waybar >/dev/null 2>&1; then
  pkill -SIGUSR2 waybar || true
else
  ($WAYBAR_CMD >/dev/null 2>&1 & disown) || true
fi

# swaync: reload if running; otherwise start
if pgrep -x swaync >/dev/null 2>&1; then
  pkill swaync && swaync & > ~/swaync.log 2>&1 || true
else
  pkill swaync && swaync & > ~/swaync2.log 2>&1 || true
fi

# nm-applet + swayosd: only restart when theme changed (to avoid needless disruption)
if [[ "${NEED_REGEN:-0}" -eq 1 ]]; then
  # nm-applet (kill & start fresh)
  if pgrep -x nm-applet >/dev/null 2>&1; then pkill -x nm-applet || true; fi
  ($NM_APPLET_CMD >/dev/null 2>&1 & disown) || true

  # swayosd-server (kill & start fresh; adjust binary name if yours differs)
  if pgrep -x swayosd-server >/dev/null 2>&1; then pkill -x swayosd-server || true; fi
  ($SWAYOSD_CMD >/dev/null 2>&1 & disown) || true
fi

echo "finish"
