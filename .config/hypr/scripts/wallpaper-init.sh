#!/usr/bin/env bash
set -euo pipefail

DEFAULT_WP="/usr/share/wallpapers/cachyos-wallpapers/Skyscraper.png"  # change me
CACHE="${HOME}/.cache/current_wallpaper"
HCONF="${HOME}/.config/hypr/hyprpaper.conf"

mkdir -p "$(dirname "$CACHE")" "$(dirname "$HCONF")"

# Ensure hyprpaper has a minimal config so it doesn't crash
if [[ ! -s "$HCONF" ]]; then
  cat >"$HCONF" <<'EOF'
splash = false
ipc = on
EOF
fi

have() { command -v "$1" >/dev/null 2>&1; }

# Start hyprpaper if not running, then wait for IPC to be ready
if ! pgrep -x hyprpaper >/dev/null; then
  hyprpaper & disown
fi

# Wait up to ~2s for IPC (hyprctl hyprpaper list should succeed)
for i in {1..20}; do
  if hyprctl hyprpaper list >/dev/null 2>&1; then break; fi
  sleep 0.1
done

# Resolve wallpaper to use (cache or default)
if [[ -f "$CACHE" ]] && [[ -f "$(cat "$CACHE")" ]]; then
  WALLPAPER="$(cat "$CACHE")"
else
  WALLPAPER="$DEFAULT_WP"
  printf '%s' "$WALLPAPER" > "$CACHE"
fi

# Preload + assign to every active monitor
hyprctl hyprpaper preload "$WALLPAPER" >/dev/null 2>&1 || true

# Iterate monitors (jq → JSON; fallback → parse text)
if have jq; then
  hyprctl -j monitors | jq -r '.[].name' | while read -r mon; do
    [[ -n "$mon" ]] || continue
    hyprctl hyprpaper wallpaper "$mon,$WALLPAPER" >/dev/null 2>&1 || true
  done
else
  # hyprctl monitors produces lines like: "Monitor DP-1 (…)"; take the 2nd field
  hyprctl monitors 2>/dev/null | awk '{print $2}' | while read -r mon; do
    [[ -n "$mon" ]] || continue
    hyprctl hyprpaper wallpaper "$mon,$WALLPAPER" >/dev/null 2>&1 || true
  done
fi

# Regenerate theme FIRST (Matugen + Wallust + reloads)
"${HOME}/.config/hypr/scripts/theme-reload.sh"

# ----- App starters (idempotent) ---------------------------------------------

start_or_reload_waybar() {
  if pgrep -x waybar >/dev/null; then
    # polite live-reload if already running
    pkill -SIGUSR2 waybar 2>/dev/null || true
  else
    waybar & disown
  fi
}

start_or_reload_swaync() {
  if pgrep -x swaync >/dev/null; then
    # reload CSS if running
    swaync-client -rs 2>/dev/null || true
  else
    swaync & disown
  fi
}

start_once_nm_applet() {
  # nm-applet advertises as nm-applet; some builds run under different argv
  pgrep -f 'nm-applet' >/dev/null || nm-applet --indicator & disown
}

start_once_swayosd() {
  pgrep -x swayosd-server >/dev/null || swayosd-server & disown
}

start_or_reload_waybar
start_or_reload_swaync
start_once_nm_applet
start_once_swayosd
