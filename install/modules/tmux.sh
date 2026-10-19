# tmux + TPM y plugins

# Mismos plugins que @tpm_plugins en tmux/tmux.conf
TMUX_PLUGINS="
tmux-plugins/tpm
tmux-plugins/tmux-sensible
tmux-plugins/tmux-yank
christoomey/vim-tmux-navigator
tmux-plugins/tmux-resurrect
alexwforsythe/tmux-which-key
"
TMUX_PLUGIN_DIR="$HOME/.tmux/plugins"

tmux_desc() { echo "tmux con temas aleatorios y plugins vía TPM"; }
tmux_supported() { return 0; }
tmux_default() { return 0; }

tmux_plugins_ok() {
  local p
  for p in $TMUX_PLUGINS; do
    [[ -d "$TMUX_PLUGIN_DIR/$(basename "$p")" ]] || return 1
    tmux_submodules_ok "$TMUX_PLUGIN_DIR/$(basename "$p")" || return 1
  done
}

# Clones antiguos sin --recurse-submodules (tmux-which-key necesita pyyaml)
tmux_submodules_ok() {
  [[ -f "$1/.gitmodules" ]] || return 0
  case "$(git -C "$1" submodule status 2>/dev/null)" in
    -* | *$'\n'-*) return 1 ;;
  esac
}

tmux_status() {
  combine_status \
    "$(status_of brew_satisfied tmux)" \
    "$(link_status "$DOTFILES/tmux" "$CONFIG_DIR/tmux")" \
    "$(link_status "$CONFIG_DIR/tmux/tmux.conf" "$HOME/.tmux.conf")" \
    "$(status_of tmux_plugins_ok)"
}

tmux_install() {
  local p f
  brew_bundle tmux
  link "$DOTFILES/tmux" "$CONFIG_DIR/tmux"
  link "$CONFIG_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"

  # Los scripts de la barra de estado necesitan permisos de ejecución
  for f in "$DOTFILES"/tmux/*.sh "$DOTFILES"/tmux/scripts/*.sh "$DOTFILES"/tmux/themes/*.sh; do
    [[ -x "$f" ]] || run chmod +x "$f"
  done

  for p in $TMUX_PLUGINS; do
    git_clone "https://github.com/$p" "$TMUX_PLUGIN_DIR/$(basename "$p")" --recurse-submodules
    if ! tmux_submodules_ok "$TMUX_PLUGIN_DIR/$(basename "$p")"; then
      run git -C "$TMUX_PLUGIN_DIR/$(basename "$p")" submodule update --init --depth 1
      log_ok "Submódulos de $(basename "$p")"
    fi
  done

  [[ "$(os_kind)" == wsl ]] && install_win32yank

  if [[ -n "${TMUX:-}" ]]; then
    log_info "Recarga la config con: prefix + R"
  fi
}
