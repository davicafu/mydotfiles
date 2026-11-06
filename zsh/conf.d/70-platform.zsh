# Linux / WSL (~/.local/bin va en 10-brew.zsh, para todas las plataformas)
if [[ "$OSTYPE" == linux* ]]; then
  bindkey "^[[H" beginning-of-line
  bindkey "^[[F" end-of-line
  bindkey "^[OH" beginning-of-line
  bindkey "^[OF" end-of-line
  bindkey "^[[3~" delete-char
  bindkey "^[[1;5D" beginning-of-line
  bindkey "^[[1;5C" end-of-line
fi
