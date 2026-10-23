# Herramientas: cada una solo si está instalada, así la shell arranca igual
# aunque falte alguna.
(( $+commands[atuin] )) && eval "$(atuin init zsh)"
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

setopt complete_aliases
