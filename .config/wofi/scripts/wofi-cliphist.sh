#!/usr/bin/env bash
set -euo pipefail

# Exit if wofi is already running
pgrep -x wofi >/dev/null && exit 0

sel="$(cliphist list | wofi --dmenu -p 'Clipboard')"
[ -z "${sel:-}" ] && exit 0
cliphist decode <<<"$sel" | wl-copy
