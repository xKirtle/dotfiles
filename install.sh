#!/usr/bin/env bash
set -euo pipefail

# nuke-and-stow.sh — Remove existing configs/icons and replace them with symlinks from the repo
# Usage:
#   ./nuke-and-stow.sh [--simulate]
#
# --simulate   Show what would happen without making changes
#
# This script replaces:
#   - ~/.config/<subdir>  with symlinks to repo/.config/<subdir>
#   - ~/.icons            with symlink to repo/.icons

SIMULATE=0
REPO_DIR="$(pwd)"
HOME_CONFIG_DIR="$HOME/.config"
HOME_ICONS_DIR="$HOME/.icons"

while (( $# )); do
  case "$1" in
    --simulate) SIMULATE=1 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

echo "==> Repo:  $REPO_DIR"
echo "==> Mode:  $([[ $SIMULATE -eq 1 ]] && echo SIMULATION || echo REAL EXECUTION)"
echo

### Handle .config subfolders
echo "==> Processing .config subfolders..."
for folder in "$REPO_DIR"/.config/*; do
  [[ -d "$folder" ]] || continue
  name="$(basename "$folder")"
  target="$HOME_CONFIG_DIR/$name"

  if [[ -e "$target" || -L "$target" ]]; then
    if [[ $SIMULATE -eq 1 ]]; then
      echo "[SIMULATE] Would remove: $target"
    else
      echo "==> Removing: $target"
      rm -rf "$target"
    fi
  fi

  if [[ $SIMULATE -eq 1 ]]; then
    echo "[SIMULATE] Would link: $target -> $folder"
  else
    echo "==> Linking: $target -> $folder"
    ln -s "$folder" "$target"
  fi
done

### Handle .icons
if [[ -d "$REPO_DIR/.icons" ]]; then
  echo
  echo "==> Processing .icons..."
  target="$HOME_ICONS_DIR"

  if [[ -e "$target" || -L "$target" ]]; then
    if [[ $SIMULATE -eq 1 ]]; then
      echo "[SIMULATE] Would remove: $target"
    else
      echo "==> Removing: $target"
      rm -rf "$target"
    fi
  fi

  if [[ $SIMULATE -eq 1 ]]; then
    echo "[SIMULATE] Would link: $target -> $REPO_DIR/.icons"
  else
    echo "==> Linking: $target -> $REPO_DIR/.icons"
    ln -s "$REPO_DIR/.icons" "$target"
  fi
fi

echo
if [[ $SIMULATE -eq 1 ]]; then
  echo "==> Simulation complete. No changes were made."
else
  echo "==> Linking complete."
fi
