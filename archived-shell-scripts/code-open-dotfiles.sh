#!/usr/bin/env bash
set -euo pipefail

# Try to source environment.d, then fallback
if [ -d "$HOME/.config/environment.d" ]; then
  set -a
  for f in "$HOME"/.config/environment.d/*.conf; do
    [ -f "$f" ] && . "$f"
  done
  set +a
fi

exec code --new-window ~/dotfiles/