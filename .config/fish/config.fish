# Set editor
set -Ux EDITOR code
set -Ux TERMINAL kitty

# Aliases
alias ls='eza -a --icons=always'
alias ll='eza -al --icons=always'
alias lt='eza -a --tree --level=1 --icons=always'
alias logout='hyprctl dispatch exit'

# Enable starship prompt
starship init fish | source

if status is-interactive; and test -t 1
    fastfetch
end