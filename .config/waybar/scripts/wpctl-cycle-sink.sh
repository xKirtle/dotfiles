#!/usr/bin/env bash
set -Eeuo pipefail

# Cycle default sink with wpctl
# Usage: wpctl-cycle-sink.sh [next|prev]
direction="${1:-next}"

# Grab only the "Sinks:" section
sink_block="$(wpctl status | awk 'BEGIN{f=0} /Sinks:/{f=1; next} /Sources:/{f=0} f')"

# All sink IDs (strip trailing dots), preserve order, dedupe
mapfile -t sinks < <(
  awk '{ for (i=1;i<=NF;i++) if ($i ~ /^[0-9]+\.$/) print $i }' \
    <<< "$sink_block" \
  | tr -d '.' \
  | awk '!seen[$0]++'
)

# Default sink (line with '*', then first token like N.)
default_sink="$(
  awk '/\*/ {
    for (i=1;i<=NF;i++) if ($i ~ /^[0-9]+\.$/) { gsub(/\./,"",$i); print $i; exit }
  }' <<< "$sink_block"
)"

if (( ${#sinks[@]} == 0 )); then
  notify-send "⚠️ No audio sinks found."
  exit 1
fi

# Fallback if default not found
: "${default_sink:=${sinks[0]}}"

# Find current index
idx=0
for i in "${!sinks[@]}"; do
  if [[ "${sinks[$i]}" == "$default_sink" ]]; then idx=$i; break; fi
done

# Select target
case "$direction" in
  prev) target="${sinks[$(( (idx - 1 + ${#sinks[@]}) % ${#sinks[@]} ))]}" ;;
  next|*) target="${sinks[$(( (idx + 1) % ${#sinks[@]} ))]}" ;;
esac

# If only one sink / or no change
if [[ "$target" == "$default_sink" ]]; then
  name="$(wpctl inspect "$target" | awk -F\" '/node.nick|node.description/ {print $2; exit}')"
  notify-send "🔊 Output unchanged" "${name:-ID $target}"
  exit 0
fi

# Switch default and notify
if wpctl set-default "$target"; then
  name="$(wpctl inspect "$target" | awk -F\" '/node.nick|node.description/ {print $2; exit}')"
  notify-send "🔊 Output switched" "${name:-ID $target}"
else
  notify-send "⚠️ Failed to switch audio output."
  exit 1
fi