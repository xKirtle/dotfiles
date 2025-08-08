#!/usr/bin/env bash
set -Eeuo pipefail

# Paths (override via env if you want)
REPO="${REPO:-$HOME/Dev/dotfiles/scripts}"
TARGET="${TARGET:-$HOME/.config/ml4w/scripts}"

# Flags
CLEAN="${CLEAN:-false}"   # set CLEAN=true to remove links in TARGET that no longer exist in REPO
DRY_RUN="${DRY_RUN:-false}"

echo "Repo:   $REPO"
echo "Target: $TARGET"
mkdir -p "$TARGET"

# Find repo scripts: *.sh OR executable files (non-dirs)
mapfile -d '' SCRIPTS < <(
  find "$REPO" -maxdepth 1 -type f \( -name "*.sh" -o -perm -u+x -o -perm -g+x -o -perm -o+x \) -print0
)

if (( ${#SCRIPTS[@]} == 0 )); then
  echo "No scripts found in $REPO (looked for *.sh or executable files)."
  exit 0
fi

link_one() {
  local src="$1"
  local base
  base="$(basename "$src")"
  local dst="$TARGET/$base"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] ln -sfn \"$src\" \"$dst\""
    if [[ ! -x "$src" ]]; then
      echo "[dry-run] chmod +x \"$src\"   # ensure executable"
    fi
    return
  fi

  ln -sfn "$src" "$dst"
  # Make sure the *target* script is executable (symlink perms don't matter)
  if [[ ! -x "$src" ]]; then
    chmod +x "$src"
  fi
  echo "Linked: $dst -> $src"
}

# Create/refresh links
for src in "${SCRIPTS[@]}"; do
  link_one "$src"
done

# Optionally remove stale links under TARGET that point into REPO but no longer exist
if [[ "$CLEAN" == "true" ]]; then
  while IFS= read -r -d '' link; do
    if [[ -L "$link" ]]; then
      tgt="$(readlink -f "$link" || true)"
      if [[ "$tgt" == "$REPO/"* && ! -e "$tgt" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
          echo "[dry-run] rm \"$link\"   # stale link"
        else
          rm "$link"
          echo "Removed stale link: $link"
        fi
      fi
    fi
  done < <(find "$TARGET" -maxdepth 1 -type l -print0)
fi

echo "Done."
