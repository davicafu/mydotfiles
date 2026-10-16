# powerlevel10k (lean, 2 líneas). La config está junto a este fichero.
if [[ -r "$BREW_PREFIX/share/powerlevel10k/powerlevel10k.zsh-theme" ]]; then
  source "$BREW_PREFIX/share/powerlevel10k/powerlevel10k.zsh-theme"
  [[ ! -f "$ZSH_DOTFILES/.p10k.zsh" ]] || source "$ZSH_DOTFILES/.p10k.zsh"
fi
