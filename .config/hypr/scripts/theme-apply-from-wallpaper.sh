#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_FILE="${HOME}/.cache/current_wallpaper"
[[ -f "$WALLPAPER_FILE" ]] || { echo "No wallpaper file: $WALLPAPER_FILE"; exit 0; }
IMG="$(cat "$WALLPAPER_FILE")"
[[ -n "$IMG" && -f "$IMG" ]] || { echo "Invalid wallpaper path: $IMG"; exit 0; }

# Read dark preference from GTK settings (GTK4 preferred, fallback GTK3)
gtk_pref() {
  local f
  for f in "$HOME/.config/gtk-4.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"; do
    [[ -f "$f" ]] || continue
    awk -F= '/^gtk-application-prefer-dark-theme=/{print $2; exit}' "$f"
  done
}
PREF="$(gtk_pref || true)"
MODE="dark"; PALETTE="dark16"
if [[ "$PREF" == "0" ]]; then MODE="light"; PALETTE="light16"; fi

# Run matugen (your matugen.toml handles templates + hyprctl reload post_hook)
if command -v matugen >/dev/null 2>&1; then
  if [[ "$MODE" == "light" ]]; then
    matugen image "$IMG" -m light || true
  else
    matugen image "$IMG" || true
  fi
fi

# Run wallust for kitty (your wallust config maps kitty.template → kitty.target)
if command -v wallust >/dev/null 2>&1; then
  wallust run --palette "$PALETTE" "$IMG" || true
fi

# Optional: do immediate reloads if you *don’t* rely on the watcher.
# Uncomment if you want instant updates without inotify:
# pkill -SIGUSR2 waybar 2>/dev/null || true
# swaync-client -rs 2>/dev/null || true
# kitty @ set-colors --all "$HOME/.config/kitty/colors-wallust.conf" >/dev/null 2>&1 || true
