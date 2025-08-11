3. Hyprland basics

Set wallpaper daemon: keep swaybg or replace with swww (smooth transitions)

Customize wofi (CSS file in ~/.config/wofi/style.css)

Customize waybar (modules, colors, font, add CPU/GPU/mem)

Configure workspaces per monitor

    Set up gaps, borders, animations

4. Essential desktop services

Notifications (mako) — already in autostart

Clipboard history (cliphist + wofi integration)

Audio device switcher (keybind + pactl set-default-sink)

Network tray (nm-applet) — already in autostart

Bluetooth manager (blueman-applet)

Screen lock (swaylock or hyprlock)

    Idle daemon (swayidle or hypridle)

5. Productivity & workflow

File manager: Thunar (already installed)

Terminal emulator: Kitty (already installed)

Code editor: VS Code (already installed)

Archive tools (p7zip, unzip, unrar)

Screenshot / annotation: keep grimblast, maybe add swappy for annotations

    Screen recording: wf-recorder or obs-studio

6. Gaming setup

Steam (steam), Proton GE

Lutris (optional)

MangoHud

Gamescope

vkBasalt

    GameMode (gamemode)

7. System extras

Automount drives (udiskie)

Power/battery management (tlp for laptops)

Night light (wlsunset)

    Backup tool (e.g. rsync or borg)

8. Backup configs & packages

Export explicit packages:
pacman -Qqe > ~/pkglist.txt

Backup dotfiles (even if they’re not “final” yet)

Document manual tweaks in SETUP_NOTES.md