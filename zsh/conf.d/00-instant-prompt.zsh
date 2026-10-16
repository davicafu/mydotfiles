# Inicio instantáneo de powerlevel10k. Tiene que ser lo primero: todo lo que
# pida input o imprima algo va después.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${USER}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${USER}.zsh"
fi
