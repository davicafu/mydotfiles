# Ghostty (terminal en macOS) + shaders

ghostty_desc() { echo "Ghostty con shaders y keybindings"; }
ghostty_supported() { [[ "$(os_kind)" == mac ]]; }
ghostty_default() { return 0; }

# Puede estar instalado desde el .dmg, sin brew
ghostty_app_ok() { [[ -d /Applications/Ghostty.app ]]; }

ghostty_status() {
  combine_status \
    "$(status_of ghostty_app_ok)" \
    "$(link_status "$DOTFILES/ghostty" "$CONFIG_DIR/ghostty")"
}

ghostty_install() {
  if ghostty_app_ok; then
    log_skip "Ghostty ya instalado"
  else
    run brew install --cask ghostty
    log_ok "Ghostty instalado"
  fi
  link "$DOTFILES/ghostty" "$CONFIG_DIR/ghostty"
}
