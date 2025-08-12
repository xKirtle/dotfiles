#!/usr/bin/env bash
set -euo pipefail

# --------- CONFIG: set this to how you get the current wallpaper ----------
# Example: if swaybg is yours, you might store it yourself when you set it.
WALLPAPER_FILE="${HOME}/.cache/current_wallpaper"   # <-- customize me
# -------------------------------------------------------------------------

# Matugen outputs (match your matugen.toml)
HYPR_COLORS="$HOME/.config/hypr/colors.conf"
WAYBAR_CSS="$HOME/.config/waybar/colors.css"
SWAYNC_CSS="$HOME/.config/swaync/colors.css"
GTK3_CSS="$HOME/.config/gtk-3.0/colors.css"
GTK4_CSS="$HOME/.config/gtk-4.0/colors.css"
WLOGOUT_CSS="$HOME/.config/wlogout/colors.css"
WOFI_CSS="$HOME/.config/wofi/style.css"

# GTK settings (watch both; some desktops write only one)
GTK3_SETTINGS="$HOME/.config/gtk-3.0/settings.ini"
GTK4_SETTINGS="$HOME/.config/gtk-4.0/settings.ini"

# Tools
have() { command -v "$1" >/dev/null 2>&1; }
need() { have "$1" || { echo "Missing: $1"; exit 1; }; }

need inotifywait
have jq || echo "Tip: install jq for nicer checks (optional)."

# Debounce simple
declare -A LAST; debounce() {
  local key="$1" now; now="$(date +%s)"
  if [[ -n "${LAST[$key]:-}" ]] && (( now - LAST[$key] < 1 )); then return 1; fi
  LAST[$key]="$now"; return 0
}

# Reload helpers
reload_waybar()      { pkill -SIGUSR2 waybar 2>/dev/null || true; }
reload_swaync_css()  { swaync-client -rs 2>/dev/null || true; }
reload_hypr()        { hyprctl reload >/dev/null 2>&1 || true; }
notif()              { have notify-send && notify-send -t 1200 "Theme updated" "$1" || true; }

# Read GTK dark preference: returns 0/1 (empty if missing)
read_gtk_dark_pref() {
  local f="$1"
  [[ -f "$f" ]] || { printf ''; return; }
  awk -F= '/^gtk-application-prefer-dark-theme=/{print $2; exit}' "$f"
}

# Run matugen for current wallpaper with desired mode (dark|light)
run_matugen_mode() {
  local mode="$1"
  local wp
  if [[ -f "$WALLPAPER_FILE" ]]; then
    wp="$(cat "$WALLPAPER_FILE")"
  else
    echo "Wallpaper file not found: $WALLPAPER_FILE"; return 1
  fi
  if [[ -z "$wp" || ! -f "$wp" ]]; then
    echo "Wallpaper path invalid: $wp"; return 1
  fi
  if [[ "$mode" == "dark" ]]; then
    matugen image "$wp"
  else
    matugen image "$wp" -m light
  fi
}

apply_darklight_from_file() {
  local settings="$1"
  local pref; pref="$(read_gtk_dark_pref "$settings")"
  [[ -z "$pref" ]] && { echo "gtk dark pref not found in $settings"; return 0; }
  if [[ "$pref" -eq 1 ]]; then
    echo "Applying matugen: dark"
    run_matugen_mode dark || true
  else
    echo "Applying matugen: light"
    run_matugen_mode light || true
  fi
}

# Initial pass: if either settings file exists, apply once
[[ -f "$GTK4_SETTINGS" ]] && apply_darklight_from_file "$GTK4_SETTINGS"
[[ -f "$GTK3_SETTINGS" ]] && apply_darklight_from_file "$GTK3_SETTINGS"

# Start watcher
echo "Watching GTK settings and matugen outputs…"
inotifywait -m -q \
  -e close_write,move,create \
  --format '%w%f' \
  "$GTK4_SETTINGS" "$GTK3_SETTINGS" \
  "$HYPR_COLORS" "$WAYBAR_CSS" "$SWAYNC_CSS" "$GTK3_CSS" "$GTK4_CSS" "$WLOGOUT_CSS" "$WOFI_CSS" \
| while read -r path; do
    debounce "$path" || continue

    case "$path" in
      "$GTK4_SETTINGS"|"$GTK3_SETTINGS")
        apply_darklight_from_file "$path"
        ;;

      "$HYPR_COLORS")
        reload_hypr
        notif "Hyprland reloaded"
        ;;

      "$WAYBAR_CSS")
        reload_waybar
        notif "Waybar style reloaded"
        ;;

      "$SWAYNC_CSS")
        reload_swaync_css
        notif "SwayNC CSS reloaded"
        ;;

      "$GTK3_CSS"|"$GTK4_CSS")
        notif "GTK apps may need restart to apply new colors"
        ;;

      "$WLOGOUT_CSS")
        notif "wlogout theme applies on next launch"
        ;;

      "$WOFI_CSS")
        notif "Wofi theme applies on next run"
        ;;
    esac
  done
