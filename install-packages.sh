#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Usage: ./install.sh <manifest> [--allow-downgrades] [--interactive]
#
# Sections recognized (case-insensitive):
#   # AUR
#   # flatpak
#
# Defaults:
# - Skips repo downgrades (installed > repo).
# - Non-interactive installs (auto-pick default provider). Use --interactive to review prompts.

err() { printf "Error: %s\n" "$*" >&2; exit 1; }
log() { printf "\n==> %s\n" "$*"; }

MANIFEST=""
ALLOW_DOWNGRADES=0
NONINTERACTIVE=0

# ---- args ----
for arg in "$@"; do
  case "$arg" in
    --allow-downgrades) ALLOW_DOWNGRADES=1 ;;
    --interactive)      NONINTERACTIVE=0 ;;
    -*)
      err "Unknown flag: $arg"
      ;;
    *)
      if [[ -z "$MANIFEST" ]]; then MANIFEST="$arg"; else err "Unexpected extra argument: $arg"; fi
      ;;
  esac
done

[[ -n "${MANIFEST}" ]] || err "Provide a manifest file path. Example: $0 dependencies.txt"
[[ -f "$MANIFEST" ]]   || err "Manifest not found: $MANIFEST"

# ---- pick AUR helper ----
if command -v paru >/dev/null 2>&1; then
  AUR_HELPER="paru"
elif command -v yay >/dev/null 2>&1; then
  AUR_HELPER="yay"
else
  err "Neither 'paru' nor 'yay' found. Install one and re-run."
fi

AUR_OPTS=( -S --needed )
if (( NONINTERACTIVE )); then
  AUR_OPTS+=( --noconfirm )
fi

# ---- parse manifest (CRLF + BOM safe) ----
shopt -s nocasematch

section=""
aur_pkgs=()
flatpaks=()
declare -A seen=()

add_pkg() {
  local bucket
  local name
  local key
  bucket="$1"
  name="$2"
  key="${bucket}::${name}"
  [[ -n "${seen[$key]:-}" ]] && return 0
  seen["$key"]=1
  if [[ "$bucket" == "aur" ]]; then
    aur_pkgs+=("$name")
  else
    flatpaks+=("$name")
  fi
}

while IFS= read -r raw || [[ -n "$raw" ]]; do
  # strip CR (CRLF) and BOM, then trim
  line="${raw//$'\r'/}"
  line="${line#$'\xEF\xBB\xBF'}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" ]] && continue

  if [[ "$line" =~ ^#[[:space:]]*aur([[:space:]]|$) ]]; then
    section="aur"; continue
  elif [[ "$line" =~ ^#[[:space:]]*flatpak([[:space:]]|$) ]]; then
    section="flatpak"; continue
  elif [[ "$line" =~ ^# ]]; then
    section=""; continue
  fi

  case "$section" in
    aur)     add_pkg "aur" "$line" ;;
    flatpak) add_pkg "flatpak" "$line" ;;
    *)       ;; # ignore lines outside known sections
  esac
done < "$MANIFEST"

# Preview
if ((${#aur_pkgs[@]})); then
  log "Parsed AUR packages (${#aur_pkgs[@]}). First 10:"
  printf '  %s\n' "${aur_pkgs[@]:0:10}"
else
  log "Parsed AUR packages: none."
fi
if ((${#flatpaks[@]})); then
  log "Parsed Flatpaks (${#flatpaks[@]}):"
  printf '  %s\n' "${flatpaks[@]}"
else
  log "Parsed Flatpaks: none."
fi

# ---- build install list (skip downgrades unless allowed) ----
to_install=()
skipped_downgrades=()

for pkg in "${aur_pkgs[@]}"; do
  if ! pacman -Q "$pkg" >/dev/null 2>&1; then
    to_install+=("$pkg")
    continue
  fi

  inst_ver="$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}')"
  repo_ver="$(pacman -Si "$pkg" 2>/dev/null | awk -F' *: *' '/^Version[[:space:]]*:/ {print $2; exit}')"

  if [[ -z "$repo_ver" ]]; then
    to_install+=("$pkg")
    continue
  fi

  if (( ! ALLOW_DOWNGRADES )) && [[ -n "$inst_ver" && -n "$repo_ver" ]] && \
     (( $(vercmp "$inst_ver" "$repo_ver") > 0 )); then
    skipped_downgrades+=("$pkg ($inst_ver > $repo_ver)")
    continue
  fi

  to_install+=("$pkg")
done

if ((${#skipped_downgrades[@]})); then
  log "Skipping repo downgrades (${#skipped_downgrades[@]}):"
  printf '  %s\n' "${skipped_downgrades[@]}"
fi

# ---- install via helper ----
if ((${#to_install[@]})); then
  log "Installing ${#to_install[@]} package(s) via ${AUR_HELPER}…"
  sudo -v || true
  "$AUR_HELPER" "${AUR_OPTS[@]}" "${to_install[@]}"
else
  log "No AUR packages to install (after skipping downgrades)."
fi

# ---- flatpaks ----
if ((${#flatpaks[@]})); then
  if ! command -v flatpak >/dev/null 2>&1; then
    log "Flatpak not found. Installing via pacman…"
    if (( NONINTERACTIVE )); then
      sudo pacman -Sy --needed --noconfirm flatpak || err "Failed to install flatpak"
    else
      sudo pacman -Sy --needed flatpak || err "Failed to install flatpak"
    fi
  fi

  if ! flatpak remote-list | awk '{print $1}' | grep -qx "flathub"; then
    log "Adding Flathub remote…"
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi

  log "Installing ${#flatpaks[@]} Flatpak(s) from Flathub…"
  for app in "${flatpaks[@]}"; do
    flatpak install -y flathub "$app"
  done
else
  log "No Flatpaks to install."
fi

log "All done."
