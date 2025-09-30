#!/usr/bin/env bash
set -euo pipefail

sock="${XDG_RUNTIME_DIR}/hypr-ssh-agent.sock"

# If the socket exists but agent is dead, clean it up
if [[ -S "$sock" ]]; then
  if ssh-add -l >/dev/null 2>&1; then
    exit 0
  else
    rm -f "$sock"
  fi
fi

# Start agent bound to our known socket; it forks and prints env (we ignore it)
ssh-agent -a "$sock" >/dev/null 2>&1 || true
