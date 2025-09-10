#!/usr/bin/env bash
# workspace-goto.sh <1-9>
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/workspace-lib.sh"

N="${1:-}"; [[ "$N" =~ ^[1-9]$ ]] || { echo "need 1..9"; exit 1; }
command -v jq >/dev/null || { notify-send "Install jq"; exit 1; }

ws_focus || exit 0
ws_wsjson
ws_clients_json

# Decide target slot using shared logic
TARGET_SLOT="$(ws_decide_target_goto "$N")"
[[ -z "$TARGET_SLOT" ]] && exit 0

# No-op if target equals current (lib already checks, but keep it cheap)
CUR="$(ws_current_local_slot)"
[[ "$CUR" == "$TARGET_SLOT" ]] && exit 0

# Jump
ws_goto_slot "$TARGET_SLOT"
