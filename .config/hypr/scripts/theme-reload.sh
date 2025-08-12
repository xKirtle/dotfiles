#!/usr/bin/env bash
set -euo pipefail

# Where Wallust writes kitty colors
KITTY_COLORS="${HOME}/.config/kitty/colors-wallust.conf"

# Prefer querying hyprpaper; fall back to our cache file (written by set-wallpaper)
get_current_wallpaper() {
  # hyprpaper IPC: "hyprctl hyprpaper list" prints lines like:
  # monitor DP-1, /path/to/image.jpg
  local from_ipc
  from_ipc="$(hyprctl hyprpaper list 2>/dev/null | awk -F', ' '/^monitor /{print $2; exit}')"
  if [[ -n "${from_ipc:-}" && -f "$from_ipc" ]]; then
    printf '%s\n' "$from_ipc"; return
  fi
  local cache="${HOME}/.cache/current_wallpaper"
  [[ -f "$cache" ]] && cat "$cache" || true
}

# Read GTK dark/light preference (GTK4 first, then GTK3)
gtk_pref() {
  local v
  for f in "$HOME/.config/gtk-4.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"; do
    [[ -f "$f" ]] || continue
    v="$(awk -F= '/^gtk-application-prefer-dark-theme=/{print $2; exit}' "$f")"
    [[ -n "${v:-}" ]] && { printf '%s' "$v"; return; }
  done
  printf '1'  # default to dark if unknown
}

IMG="$(get_current_wallpaper || true)"
[[ -n "${IMG:-}" && -f "$IMG" ]] || { echo "theme-reload: no valid wallpaper found"; exit 0; }

PREF="$(gtk_pref || true)"
MODE="dark"; PALETTE="dark16"
[[ "$PREF" == "0" ]] && { MODE="light"; PALETTE="light16"; }

# 1) Matugen (your matugen.toml handles all template outputs + hyprctl reload via post_hook)
if command -v matugen >/dev/null 2>&1; then
  if [[ "$MODE" == "light" ]]; then
    matugen image "$IMG" -m light || true
  else
    matugen image "$IMG" -m dark || true
  fi
fi

# 2) Wallust (for kitty, etc.)
if command -v wallust >/dev/null 2>&1; then
  wallust run --palette "$PALETTE" "$IMG" || true
fi

# 3) Live reload the usual suspects (instant, no flicker)
pkill -SIGUSR2 waybar 2>/dev/null || true            # Waybar CSS/config reload

# Only attempt if the daemon is running; otherwise this call waits forever.
if pgrep -x swaync >/dev/null 2>&1; then
  swaync-client -rs >/dev/null 2>&1 || true
else
  echo "swaync not running yet; skipping CSS reload"
fi

kitty @ set-colors --all "$KITTY_COLORS" >/dev/null 2>&1 || true  # Kitty colors
# Hyprland: matugen’s post_hook already runs "hyprctl reload"; keep a fallback if you want:
# hyprctl reload >/dev/null 2>&1 || true

echo "finish"