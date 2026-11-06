# Entorno base de Homebrew (detección macOS vs Linux)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

BREW_PREFIX="$(brew --prefix)"

# ~/.cargo/bin (rustup, cargo install) y ~/.local/bin delante de brew en
# todas las plataformas: en ~/.local/bin instalan Claude Code, Gentle Shell,
# Zed (linux) y win32yank (WSL). Solo si no están ya; cargo, si existe.
[[ -d $HOME/.cargo/bin ]] && (( ! ${path[(Ie)$HOME/.cargo/bin]} )) &&
  path=("$HOME/.cargo/bin" $path)
(( ${path[(Ie)$HOME/.local/bin]} )) || path=("$HOME/.local/bin" $path)
export PATH
