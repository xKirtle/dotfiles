#!/bin/bash

REPO="$HOME/Dev/dotfiles/.config/hypr/conf"
TARGET="$HOME/.config/hypr/conf"

echo "🔁 Syncing Hyprland config overlays..."

# 1. Full override: replace target with source statement (don't touch source file!)
for file in "$REPO/full_override/"*; do
    [ -f "$file" ] || continue
    filename=$(basename "$file")
    target="$TARGET/$filename"

    echo "🧹 Removing $target (if exists)..."
    rm -f "$target"

    # Replace full $HOME path with literal $HOME for portability
    relative_path="${file/#$HOME/\$HOME}"

    echo "➕ Creating new $filename that sources your custom config..."

    {
        echo "# Overridden by kirtle config"
        echo "source = $relative_path"
    } > "$target"
done

# 2. Source-after strategy
for file in "$REPO/source_after/"*; do
    [ -f "$file" ] || continue
    name=$(basename "$file")
    target_file="$TARGET/$name"

    if [ ! -f "$target_file" ]; then
        echo "⚠️  Target $target_file doesn't exist, skipping."
        continue
    fi

    relative_path="${file/#$HOME/\$HOME}"
    source_line="source = $relative_path"

    if ! grep -Fxq "$source_line" "$target_file"; then
        echo "➕ Appending source to $name"
        echo -e "\n# Added by kirtle config\n$source_line" >> "$target_file"
    else
        echo "✅ $name already sources your file"
    fi
done

echo "✅ Sync complete!"
