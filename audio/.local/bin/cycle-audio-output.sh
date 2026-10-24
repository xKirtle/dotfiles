#!/bin/bash
# cycle-audio-output.sh

SPEAKERS_MATCH="Ryzen HD Audio Controller Digital Stereo"
HEADPHONES_MATCH="Scarlett Solo 4th Gen Headphones"

status=$(wpctl status)

current_line=$(echo "$status" | grep '\*' | grep -E "$SPEAKERS_MATCH|$HEADPHONES_MATCH")

if echo "$current_line" | grep -q "$SPEAKERS_MATCH"; then
    target_name="$HEADPHONES_MATCH"
    label="Headphones"
else
    target_name="$SPEAKERS_MATCH"
    label="Speakers"
fi

target_id=$(echo "$status" | grep "$target_name" | grep -oE '[0-9]+\.' | head -1 | tr -d '.')

if [ -z "$target_id" ]; then
    notify-send "Audio Output" "Device not found: $label" -u critical -t 3000
    exit 1
fi

wpctl set-default "$target_id"
# Caelestia shows its own "audio output changed" toast, so no notification here
