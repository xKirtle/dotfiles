#!/usr/bin/env bash
set -euo pipefail

REPO="${REPO:-$HOME/Dev/dotfiles/.config/waybar/themes}"
TARGET="${TARGET:-$HOME/.config/waybar/themes}"

echo "Repo:   $REPO"
echo "Target: $TARGET"
mkdir -p "$TARGET"

link_files_only() {
  local src="$1"
  local dst="$2"
  mkdir -p "$dst"
  # Symlink only regular files (exclude directories)
  while IFS= read -r -d '' file; do
    ln -sfn "$file" "$dst/$(basename "$file")"
  done < <(find "$src" -maxdepth 1 -type f -print0)
}

shopt -s nullglob

for theme_dir in "$REPO"/*; do
  [[ -d "$theme_dir" ]] || continue
  theme_name="$(basename "$theme_dir")"

  # Look for variant subfolders (e.g., light, dark, etc.)
  variants=("$theme_dir"/*/)
  if (( ${#variants[@]} > 0 )); then
    # Theme has variants: create TARGET/<theme>/<variant> and link files from each variant
    for variant_dir in "${variants[@]}"; do
      [[ -d "$variant_dir" ]] || continue
      variant_name="$(basename "$variant_dir")"
      dst="$TARGET/$theme_name/$variant_name"
      echo "→ Theme '$theme_name' variant '$variant_name'"
      link_files_only "$variant_dir" "$dst"
    done
  fi
    # Also link files directly under TARGET/<theme>
    dst="$TARGET/$theme_name"
    echo "→ Theme '$theme_name' (no variants)"
    link_files_only "$theme_dir" "$dst"
done

echo "Done. If ML4W is open, relaunch Waybar or run its theme switcher."
