#!/usr/bin/env bash
set -Eeuo pipefail

# Unified setup for Hyprland overlays, Waybar themes, and ML4W scripts
# Flags:
#   --dry-run            : Show what would happen, make no changes
#   --clean              : Remove stale links where applicable
#   --only hypr|waybar|scripts : Run only a specific task (can be passed multiple times)
#   --repo-hypr PATH     : Override Hypr repo path
#   --repo-waybar PATH   : Override Waybar themes repo path
#   --repo-scripts PATH  : Override scripts repo path
#   --target-hypr PATH   : Override Hypr target path
#   --target-waybar PATH : Override Waybar target path
#   --target-scripts PATH: Override ML4W scripts target path
#   -v/--verbose         : Chatty logging
#
# Defaults:
#   Hypr repo    : $HOME/Dev/dotfiles/.config/hypr/conf
#   Hypr target  : $HOME/.config/hypr/conf
#   Waybar repo  : $HOME/Dev/dotfiles/.config/waybar/themes
#   Waybar target: $HOME/.config/waybar/themes
#   Scripts repo : $HOME/Dev/dotfiles/scripts
#   Scripts tgt  : $HOME/.config/ml4w/scripts
#
# Example:
#   ./install-all.sh --dry-run --only waybar --only scripts --clean

DRY_RUN=false
CLEAN=false
VERBOSE=false
ONLY=()

# Resolve script's absolute directory (follows symlinks too)
SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)"
# Go one level up from /setup/
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO_HYPR="$REPO_ROOT/.config/hypr/conf"
TARGET_HYPR="$HOME/.config/hypr/conf"

REPO_WAYBAR="$REPO_ROOT/.config/waybar/themes"
TARGET_WAYBAR="$HOME/.config/waybar/themes"

REPO_SCRIPTS="$REPO_ROOT/scripts"
TARGET_SCRIPTS="$HOME/.config/ml4w/scripts"

log() { printf "%s\n" "$*"; }
vlog() { $VERBOSE && printf "%s\n" "$*" || true; }

do_mkdir() {
  local d="$1"
  if [[ "$DRY_RUN" == "true" ]]; then vlog "[dry-run] mkdir -p \"$d\""; else mkdir -p "$d"; fi
}

do_ln_sfn() {
  local src="$1" dst="$2"
  if [[ "$DRY_RUN" == "true" ]]; then vlog "[dry-run] ln -sfn \"$src\" \"$dst\""; else ln -sfn "$src" "$dst"; fi
}

do_rm() {
  local p="$1"
  if [[ "$DRY_RUN" == "true" ]]; then vlog "[dry-run] rm -f \"$p\""; else rm -f "$p"; fi
}

ensure_executable() {
  local p="$1"
  if [[ -f "$p" && ! -x "$p" ]]; then
    if [[ "$DRY_RUN" == "true" ]];
    then vlog "[dry-run] chmod +x \"$p\""
    else chmod +x "$p"
    fi
  fi
}

parse_args() {
  while (( $# )); do
    case "$1" in
      --dry-run) DRY_RUN=true ;;
      --clean) CLEAN=true ;;
      -v|--verbose) VERBOSE=true ;;
      --only) shift; ONLY+=("$1") ;;
      --repo-hypr) shift; REPO_HYPR="$1" ;;
      --repo-waybar) shift; REPO_WAYBAR="$1" ;;
      --repo-scripts) shift; REPO_SCRIPTS="$1" ;;
      --target-hypr) shift; TARGET_HYPR="$1" ;;
      --target-waybar) shift; TARGET_WAYBAR="$1" ;;
      --target-scripts) shift; TARGET_SCRIPTS="$1" ;;
      -h|--help)
        sed -n '1,80p' "$0"; exit 0 ;;
      *) log "Unknown arg: $1"; exit 2 ;;
    esac
    shift
  done
}

should_run() {
  # If no --only provided, run all. Otherwise check membership.
  local name="$1"
  if (( ${#ONLY[@]} == 0 )); then return 0; fi
  for o in "${ONLY[@]}"; do
    if [[ "$o" == "$name" ]]; then return 0; fi
  done
  return 1
}

########################################
# Task: Hyprland overlays
########################################
install_hypr() {
  log "🔁 Syncing Hyprland config overlays…"
  do_mkdir "$TARGET_HYPR"

  # 1) full_override: write tiny files that source the repo files
  local src="$REPO_HYPR/full_override"
  if [[ -d "$src" ]]; then
    for file in "$src"/*; do
      [[ -f "$file" ]] || continue
      local filename target rel
      filename="$(basename "$file")"
      target="$TARGET_HYPR/$filename"

      if [[ "$REPO_ROOT" == "$HOME"* ]]; then
        rel="${file/#$HOME/\$HOME}"   # -> $HOME/...
      else
        rel="$file"                   # -> /abs/path/...
      fi

      if [[ "$DRY_RUN" == "true" ]]; then
        vlog "[dry-run] write source stub to $target (source = $rel)"
      else
        printf "# Overridden by dotfiles\nsource = %s\n" "$rel" > "$target"
      fi
    done
  fi

  # 2) source_after: append source lines at end of target files (create if missing)
  local src2="$REPO_HYPR/source_after"
  if [[ -d "$src2" ]]; then
    for file in "$src2"/*; do
      [[ -f "$file" ]] || continue
      local name target rel
      name="$(basename "$file")"
      target="$TARGET_HYPR/$name"

      if [[ "$REPO_ROOT" == "$HOME"* ]]; then
        rel="${file/#$HOME/\$HOME}"
      else
        rel="$file"
      fi

      if [[ "$DRY_RUN" == "true" ]]; then
        vlog "[dry-run] ensure $target ends with: source = $rel"
      else
        touch "$target"
        if ! grep -qF "source = $rel" "$target"; then
          printf "\n# Added by dotfiles\nsource = %s\n" "$rel" >> "$target"
        fi
      fi
    done
  fi


  log "✅ Hypr sync complete."
}

########################################
# Task: Waybar themes
########################################
install_waybar() {
  log "🎨 Linking Waybar themes…"
  do_mkdir "$TARGET_WAYBAR"

  shopt -s nullglob
  for theme_dir in "$REPO_WAYBAR"/*; do
    [[ -d "$theme_dir" ]] || continue
    theme_name="$(basename "$theme_dir")"

    # detect variants
    variants=("$theme_dir"/*/)
    if (( ${#variants[@]} > 0 )); then
      for variant_dir in "${variants[@]}"; do
        [[ -d "$variant_dir" ]] || continue
        variant_name="$(basename "$variant_dir")"
        dst="$TARGET_WAYBAR/$theme_name/$variant_name"
        do_mkdir "$dst"
        while IFS= read -r -d '' f; do
          do_ln_sfn "$f" "$dst/$(basename "$f")"
        done < <(find "$variant_dir" -maxdepth 1 -type f -print0)
      done
    else
      dst="$TARGET_WAYBAR/$theme_name"
      do_mkdir "$dst"
      while IFS= read -r -d '' f; do
        do_ln_sfn "$f" "$dst/$(basename "$f")"
      done < <(find "$theme_dir" -maxdepth 1 -type f -print0)
    fi
  done

  # Optional cleaning
  if [[ "$CLEAN" == "true" ]]; then
    while IFS= read -r -d '' link; do
      if [[ -L "$link" ]]; then
        tgt="$(readlink -f "$link" || true)"
        if [[ "$tgt" == "$REPO_WAYBAR/"* && ! -e "$tgt" ]]; then
          do_rm "$link"
          vlog "Removed stale link: $link"
        fi
      fi
    done < <(find "$TARGET_WAYBAR" -type l -print0)
  fi

  # Restart Waybar via ML4W's launcher
  if [[ "$DRY_RUN" == "true" ]]; then
    vlog "[dry-run] ~/.config/waybar/launch.sh"
  else
    if [[ -x "$HOME/.config/waybar/launch.sh" ]]; then
      "$HOME/.config/waybar/launch.sh"
      log "🔄 Waybar restarted."
    else
      log "⚠️ Waybar launch script not found or not executable."
    fi
  fi

  log "✅ Waybar themes linked."
}

########################################
# Task: ML4W scripts
########################################
install_scripts() {
  log "🔗 Linking ML4W scripts…"
  do_mkdir "$TARGET_SCRIPTS"

  mapfile -d '' SCRIPTS < <(find "$REPO_SCRIPTS" -maxdepth 1 -type f \( -name "*.sh" -o -perm -u+x -o -perm -g+x -o -perm -o+x \) -print0)
  if (( ${#SCRIPTS[@]} == 0 )); then
    log "No scripts found in $REPO_SCRIPTS"; return 0
  fi
  for src in "${SCRIPTS[@]}"; do
    local dst="$TARGET_SCRIPTS/$(basename "$src")"
    do_ln_sfn "$src" "$dst"
    ensure_executable "$src"
  done

  if [[ "$CLEAN" == "true" ]]; then
    while IFS= read -r -d '' link; do
      if [[ -L "$link" ]]; then
        local tgt; tgt="$(readlink -f "$link" || true)"
        if [[ "$tgt" == "$REPO_SCRIPTS/"* && ! -e "$tgt" ]]; then
          do_rm "$link"
          vlog "Removed stale link: $link"
        fi
      fi
    done < <(find "$TARGET_SCRIPTS" -maxdepth 1 -type l -print0)
  fi

  log "✅ ML4W scripts linked."
}

setup_dotfiles_env() {
  local envd="$HOME/.config/environment.d"
  if [[ "$DRY_RUN" == "true" ]]; then
    vlog "[dry-run] mkdir -p \"$envd\""
    vlog "[dry-run] write $envd/10-dotfiles.conf with DOTFILES=$REPO_ROOT"
    vlog "[dry-run] systemctl --user import-environment DOTFILES"
    vlog "[dry-run] dbus-update-activation-environment --systemd DOTFILES"
  else
    mkdir -p "$envd"
    printf 'DOTFILES=%s\n' "$REPO_ROOT" > "$envd/10-dotfiles.conf"
    systemctl --user import-environment DOTFILES || true
    dbus-update-activation-environment --systemd DOTFILES || true
  fi
  log "🌱 DOTFILES set to: $REPO_ROOT"
}

main() {
  setup_dotfiles_env
  parse_args "$@"
  log "Repo/Target overview:"
  log "  Hypr   : $REPO_HYPR  -> $TARGET_HYPR"
  log "  Waybar : $REPO_WAYBAR -> $TARGET_WAYBAR"
  log "  Scripts: $REPO_SCRIPTS -> $TARGET_SCRIPTS"
  $DRY_RUN && log "(dry-run mode)"
  $CLEAN && log "(clean mode)"

  if should_run hypr; then install_hypr; else vlog "Skipping hypr"; fi
  if should_run waybar; then install_waybar; else vlog "Skipping waybar"; fi
  if should_run scripts; then install_scripts; else vlog "Skipping scripts"; fi

  log "🎉 All done."
}

main "$@"
