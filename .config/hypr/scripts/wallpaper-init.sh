#!/usr/bin/env bash
set -euo pipefail

# --- config ------------------------------------------------------------------
DEFAULT_WP="/usr/share/wallpapers/cachyos-wallpapers/Skyscraper.png"  # change me
HCONF="${HCONF:-$HOME/.config/hypr/hyprpaper.conf}"
WPF_FILE="${WPF_FILE:-$HOME/.cache/current_wallpaper}"

mkdir -p -- "$(dirname "$HCONF")" "$(dirname "$WPF_FILE")"

# Ensure minimal hyprpaper.conf exists with IPC on (do NOT embed wallpapers here)
if [[ ! -s "$HCONF" ]]; then
  cat >"$HCONF" <<'EOF'
splash = false
ipc = on
EOF
fi

# Ensure hyprpaper is running (IPC requires it)
if ! pgrep -x hyprpaper >/dev/null 2>&1; then
  hyprpaper & disown
  # tiny pause so IPC is ready
  sleep 0.2
fi

# Choose image:
# 1) previously cached current wallpaper (if file exists),
# 2) otherwise DEFAULT_WP.
pick_img() {
  local img=""
  if [[ -f "$WPF_FILE" ]]; then
    img="$(awk 'NF{print; exit}' "$WPF_FILE" 2>/dev/null || true)"
  fi
  if [[ -z "$img" || ! -f "$img" ]]; then
    img="$DEFAULT_WP"
  fi
  # normalize to absolute path if possible
  if rp="$(realpath -m -- "$img" 2>/dev/null)"; then
    printf '%s\n' "$rp"
  else
    printf '%s\n' "$img"
  fi
}

IMG="$(pick_img)"
if [[ -z "$IMG" || ! -f "$IMG" ]]; then
  echo "[wallpaper-init] No valid wallpaper found (checked $WPF_FILE and DEFAULT_WP). Exiting." >&2
  exit 0
fi

# Preload + set on all monitors (best-effort)
hyprctl hyprpaper preload "$IMG" >/dev/null 2>&1 || true
hyprctl -j monitors | jq -r '.[].name' | while read -r mon; do
  [[ -n "$mon" ]] || continue
  hyprctl hyprpaper wallpaper "$mon,$IMG" >/dev/null 2>&1 || true
done

# Persist current wallpaper path for later runs
printf '%s\n' "$IMG" > "$WPF_FILE"

# Hand off to theme-reload (it will decide to skip or regenerate and (re)start panels)
"$HOME/.config/hypr/scripts/theme-reload.sh"

exit 0
