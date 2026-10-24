#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# ---- QoL ----
[[ -r /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion

# History: big, deduped, shared across terminals
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend checkwinsize cdspell autocd globstar
PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

export EDITOR=nano
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# Modern replacements
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --git --group-directories-first'
alias la='eza -la --icons --git --group-directories-first'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --paging=never'
alias ..='cd ..'
alias ...='cd ../..'
alias update='paru -Syu'

# fzf: Ctrl-R history, Ctrl-T files, Alt-C dirs (uses fd)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border \
--color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8 \
--color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC \
--color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8"
command -v fzf >/dev/null && eval "$(fzf --bash)"

# zoxide: `z foo` jumps to frecent dirs
command -v zoxide >/dev/null && eval "$(zoxide init bash)"

# starship prompt
command -v starship >/dev/null && eval "$(starship init bash)"

# Caelestia colour scheme for new terminals (running ones get it live when the scheme changes)
[[ -t 1 && -r ~/.local/state/caelestia/sequences.txt ]] && command cat ~/.local/state/caelestia/sequences.txt  # not the bat alias
