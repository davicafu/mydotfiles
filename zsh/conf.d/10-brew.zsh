# Entorno base de Homebrew (detección macOS vs Linux)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

BREW_PREFIX="$(brew --prefix)"

# ~/.local/bin delante en todas las plataformas: ahí instalan Claude Code,
# Gentle Shell, Zed (linux) y win32yank (WSL). Solo si no está ya.
(( ${path[(Ie)$HOME/.local/bin]} )) || path=("$HOME/.local/bin" $path)
export PATH
