# Aliases
# Cada herramienta solo se usa si está instalada; si no, quedan los comandos del sistema.
if (( $+commands[eza] )); then
  alias ls="eza --icons"
  alias ll="eza -lah --icons"
  alias la="eza -a --icons"
  alias lt="eza --tree --level=2 --icons"
else
  alias ll="ls -lah"
  alias la="ls -A"
  (( $+commands[tree] )) && alias lt="tree -L 2"
fi

(( $+commands[bat] )) && alias cat="bat --paging=never --style=plain"
(( $+commands[fd] )) && alias find="fd"
(( $+commands[rg] )) && alias grep="rg"

alias tdev="$HOME/.config/tmux/layout-dev.sh"
