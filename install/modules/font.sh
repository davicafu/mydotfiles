# Inconsolata Nerd Font (iconos para p10k, eza, lualine...)

FONT_VERSION="v3.4.0"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/$FONT_VERSION/Inconsolata.zip"

font_desc() { echo "Inconsolata Nerd Font $FONT_VERSION"; }
font_supported() { [[ "$(os_kind)" != wsl ]]; }
font_default() { return 0; }

font_dir() {
  if [[ "$(os_kind)" == mac ]]; then
    echo "$HOME/Library/Fonts"
  else
    echo "$HOME/.local/share/fonts"
  fi
}

font_installed() { compgen -G "$(font_dir)/InconsolataNerdFont*" >/dev/null; }

font_status() { status_of font_installed; }

font_install() {
  if font_installed; then
    log_skip "Fuente ya instalada en $(font_dir)"
  else
    fetch_zip "$FONT_URL" "$(font_dir)"
    [[ "$(os_kind)" == linux ]] && run fc-cache -f
    log_ok "Fuente instalada en $(font_dir)"
  fi
  log_info "Recuerda usar 'Inconsolata Nerd Font' como fuente del terminal"
}
