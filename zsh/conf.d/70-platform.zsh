# WSL / Linux
if grep -qi microsoft /proc/version 2>/dev/null; then
  export PATH="$HOME/.local/bin:$PATH"
fi

if [[ "$OSTYPE" == linux* ]]; then
  bindkey "^[[H" beginning-of-line
  bindkey "^[[F" end-of-line
  bindkey "^[OH" beginning-of-line
  bindkey "^[OF" end-of-line
  bindkey "^[[3~" delete-char
  bindkey "^[[1;5D" beginning-of-line
  bindkey "^[[1;5C" end-of-line
fi
