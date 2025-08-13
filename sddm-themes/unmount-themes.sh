#!/usr/bin/env bash
set -euo pipefail

# Unmount any mounts in /usr/share/sddm/themes that match subfolders of this dir

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Re-running with sudo..."
    exec sudo -E bash "$0" "$@"
  fi
}

src_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
dst_root="/usr/share/sddm/themes"

require_root

shopt -s nullglob
for src in "$src_root"/*/; do
  name="$(basename "$src")"
  dst="$dst_root/$name"

  if mountpoint -q "$dst"; then
    echo "Unmounting: $dst"
    umount "$dst"
  else
    echo "Not mounted: $dst"
  fi
done

echo "Done."
