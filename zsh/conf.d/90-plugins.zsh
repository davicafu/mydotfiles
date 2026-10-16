# zsh-autosuggestions y zsh-syntax-highlighting se cargan en el primer prompt,
# cuando ya se ha leído todo ~/.zshrc. Así syntax-highlighting queda siempre lo
# último, aunque otros instaladores añadan cosas debajo en ~/.zshrc.
_mydotfiles_load_plugins() {
  add-zsh-hook -d precmd _mydotfiles_load_plugins
  unfunction _mydotfiles_load_plugins
  local plugin
  for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    [[ -r "$BREW_PREFIX/share/$plugin/$plugin.zsh" ]] && source "$BREW_PREFIX/share/$plugin/$plugin.zsh"
  done
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _mydotfiles_load_plugins
