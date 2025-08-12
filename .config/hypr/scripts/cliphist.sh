#!/usr/bin/env bash
set -euo pipefail

# Optional: point to a dedicated wofi style for this picker
STYLE="${HOME}/.config/wofi/style.css"
STYLE_FLAG=()
[ -f "$STYLE" ] && STYLE_FLAG=(--style "$STYLE")

case "${1:-}" in
  d)
    # Delete an entry
    # (cliphist delete reads the selected line from stdin, same as rofi flow)
    sel="$(cliphist list | wofi --dmenu --prompt 'Delete' -i -l 20 --cache-file /dev/null "${STYLE_FLAG[@]}")" || exit 0
    [ -n "$sel" ] && printf '%s\n' "$sel" | cliphist delete
    ;;

  w)
    # Wipe all entries (confirm)
    choice="$(printf 'Clear\nCancel\n' | wofi --dmenu --prompt 'Cliphist' -i -l 2 --cache-file /dev/null "${STYLE_FLAG[@]}")" || exit 0
    [ "$choice" = "Clear" ] && cliphist wipe
    ;;

  *)
    # Pick and copy to clipboard
    sel="$(cliphist list | wofi --dmenu --prompt 'Clipboard' -i -l 20 --cache-file /dev/null "${STYLE_FLAG[@]}")" || exit 0
    [ -n "$sel" ] && printf '%s\n' "$sel" | cliphist decode | wl-copy
    ;;
esac
