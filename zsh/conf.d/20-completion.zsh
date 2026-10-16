# Autocompletado. El dump va a la caché, fuera del repo.
fpath=("$BREW_PREFIX/share/zsh/site-functions" $fpath)

autoload -Uz compinit
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
compinit -C -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
