#!/usr/bin/env bash
set -euo pipefail

# Run from inside "SDDM Themes" (this script's directory).
# Mounts each subfolder to /usr/share/sddm/themes/<name>.
# Defaults: non-persistent (dev) + read-only.
# Flags:
#   --persist   also add/update /etc/fstab so mounts survive reboots
#   --rw        mount read-write (default ro)

want_persist=0
want_rw=0
for a in "$@"; do
  case "$a" in
    --persist) want_persist=1 ;;
    --rw)      want_rw=1 ;;
    *) echo "Usage: $0 [--persist] [--rw]"; exit 2 ;;
  esac
done

require_root() { [[ $EUID -eq 0 ]] || exec sudo -E bash "$0" "$@"; }
require_root "$@"

src_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
dst_root="/usr/share/sddm/themes"
mkdir -p "$dst_root"

# Escape for fstab (spaces, tabs, backslashes)
esc_fstab() {
  local s="$1"
  s="${s//\\/\\\\}"; s="${s// /\\040}"; s="${s//	/\\011}"
  printf '%s' "$s"
}

tag="# managed-by sddm-themes"

# Add or update a tagged /etc/fstab line for mountpoint $2 from source $1 with options $3
ensure_fstab_line() {
  local src="$1" dst="$2" opts="$3"
  local src_e dst_e
  src_e="$(esc_fstab "$src")"
  dst_e="$(esc_fstab "$dst")"

  touch /etc/fstab

  # If there is a line for this mountpoint with our tag, replace it; if there is an untagged one, warn and skip.
  if grep -E "^[^#].*[[:space:]]$(printf '%s' "$dst_e" | sed 's/[.[\*^$()+?{}|]/\\&/g')([[:space:]]|$)" /etc/fstab >/dev/null; then
    if grep -E "^[^#].*[[:space:]]$dst_e[[:space:]].*$tag$" /etc/fstab >/dev/null; then
      awk -v dst="$dst_e" -v src="$src_e" -v opts="$opts" -v tag="$tag" '
        $2==dst && $0 ~ tag { print src, dst, "none", opts, "0 0", tag; next }
        { print }
      ' /etc/fstab > /etc/fstab.tmp && mv /etc/fstab.tmp /etc/fstab
    else
      echo "WARNING: /etc/fstab already has an entry for $dst without our tag. Skipping persist for this one." >&2
      return 1
    fi
  else
    echo "$src_e $dst_e none $opts 0 0 $tag" >> /etc/fstab
  fi
}

# Iterate each immediate subdirectory (theme)
shopt -s nullglob
themes=( "$src_root"/*/ )
if (( ${#themes[@]} == 0 )); then
  echo "No theme subfolders found in: $src_root"
  exit 0
fi

for src in "${themes[@]}"; do
  name="$(basename "$src")"
  dst="$dst_root/$name"
  mkdir -p "$dst"

  if (( want_persist )); then
    opts="bind,$([[ $want_rw -eq 1 ]] && echo rw || echo ro)"
    if ensure_fstab_line "$src" "$dst" "$opts"; then
      # Mount using fstab
      if mountpoint -q "$dst"; then
        mount -o "remount,$opts" "$dst"
      else
        mount "$dst"
      fi
      echo "Persisted + mounted: $src -> $dst ($([[ $want_rw -eq 1 ]] && echo rw || echo ro))"
    else
      # Fallback to dev mount if fstab entry skipped due to conflict
      if mountpoint -q "$dst"; then
        mount -o "remount,bind,$([[ $want_rw -eq 1 ]] && echo rw || echo ro)" "$dst"
      else
        mount --bind "$src" "$dst"
        mount -o "remount,bind,$([[ $want_rw -eq 1 ]] && echo rw || echo ro)" "$dst"
      fi
      echo "Mounted (non-persistent due to fstab conflict): $src -> $dst"
    fi
  else
    # Dev (non-persistent) mount
    if mountpoint -q "$dst"; then
      mount -o "remount,bind,$([[ $want_rw -eq 1 ]] && echo rw || echo ro)" "$dst"
    else
      mount --bind "$src" "$dst"
      mount -o "remount,bind,$([[ $want_rw -eq 1 ]] && echo rw || echo ro)" "$dst"
    fi
    echo "Mounted (dev): $src -> $dst ($([[ $want_rw -eq 1 ]] && echo rw || echo ro))"
  fi
done

echo "All done."
