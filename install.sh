#!/usr/bin/env bash
# Link the dotfiles into $HOME with GNU Stow and enable the user services.
#   ./install.sh            all packages
#   ./install.sh hypr kitty only these
# Existing real files/dirs at the targets make stow refuse (nothing is overwritten);
# move them aside first. system/ is not stowed: see system/README.md.
# Before stowing, every *.template file in the chosen packages is rendered next to itself
# (foo.json.template -> foo.json) with the private values from .env (see .env.example).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
command -v stow >/dev/null || { echo "needs GNU Stow: sudo pacman -S stow" >&2; exit 1; }

packages=("$@")
if [[ ${#packages[@]} -eq 0 ]]; then
    for d in */; do
        d=${d%/}
        [[ "$d" == system || "$d" == docs ]] || packages+=("$d")
    done
fi

# Make sure shared parents exist as real dirs, so stow links the per-app dirs inside them
# instead of folding e.g. all of ~/.config/systemd/user into one package.
mkdir -p ~/.config/systemd/user ~/.local/bin ~/.config/quickshell ~/.local/share/applications

# --- Render *.template files with the values from .env ---------------------------------
# Only ${VAR} / $VAR names defined in .env are replaced, so any other `$` text is left alone.
# .env is parsed (not sourced): KEY=value per line, optional surrounding quotes stripped.
load_env() {
    local line key val
    env_vars=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
        if [[ ! "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            echo ".env: can't parse line: $line" >&2; exit 1
        fi
        key=${BASH_REMATCH[1]} val=${BASH_REMATCH[2]}
        if [[ "$val" =~ ^\"(.*)\"$ || "$val" =~ ^\'(.*)\'$ ]]; then val=${BASH_REMATCH[1]}; fi
        export "$key=$val"
        env_vars+=("$key")
    done < .env
}

templates=()
for pkg in "${packages[@]}"; do
    [[ -d "$pkg" ]] || continue
    while IFS= read -r -d '' t; do templates+=("$t"); done \
        < <(find "$pkg" -name '*.template' -type f -print0)
done
if [[ ${#templates[@]} -gt 0 ]]; then
    if [[ ! -f .env ]]; then
        echo "error: .env is missing; these templates need it:" >&2
        printf '  %s\n' "${templates[@]}" >&2
        echo "create it with: cp .env.example .env  (then fill in the values)" >&2
        exit 1
    fi
    load_env
    shell_format=$(printf '${%s} ' "${env_vars[@]}")
    for t in "${templates[@]}"; do
        out=${t%.template}
        # Warn about placeholders that .env doesn't define (they'd stay literal).
        for v in $(grep -oE '\$\{[A-Za-z_][A-Za-z0-9_]*\}' "$t" | sort -u | tr -d '${}'); do
            [[ " ${env_vars[*]} " == *" $v "* ]] || echo "warning: $t uses \${$v}, not set in .env" >&2
        done
        tmp=$(mktemp "$out.XXXXXX")
        envsubst "$shell_format" < "$t" > "$tmp"
        chmod --reference="$t" "$tmp"
        if [[ -f "$out" ]] && cmp -s "$tmp" "$out"; then
            rm -f "$tmp"            # unchanged: keep the file (and its mtime) as is
        else
            mv -f "$tmp" "$out"
            echo "rendered $out"
        fi
    done
fi

stow --target="$HOME" --restow "${packages[@]}"
echo "linked: ${packages[*]}"

systemctl --user daemon-reload
for unit in awww.service themectl-sync.service paru-aur-completion.timer \
            calendar-sync.timer calendar-remind.service; do
    [[ -e ~/.config/systemd/user/$unit ]] && systemctl --user enable "$unit" >/dev/null 2>&1 && echo "enabled $unit"
done
echo "done. Apply Hyprland changes with: hyprctl reload"
