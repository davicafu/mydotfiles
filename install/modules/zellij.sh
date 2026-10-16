# zellij (multiplexor opcional) con layouts zjstatus

# Ruta absoluta con la que están escritos los layouts
ZELLIJ_LAYOUT_HOME="/home/david"

zellij_desc() { echo "zellij con layouts zjstatus (opcional)"; }
zellij_supported() { return 0; }
zellij_default() { return 1; }

zellij_status() {
  combine_status \
    "$(status_of brew_satisfied zellij)" \
    "$(link_status "$DOTFILES/zellij" "$CONFIG_DIR/zellij")"
}

zellij_install() {
  local layouts f
  brew_bundle zellij
  link "$DOTFILES/zellij" "$CONFIG_DIR/zellij"

  # Los plugins no funcionan con rutas relativas: los layouts llevan $HOME
  # escrito a mano. Reescribirlos cambia ficheros del repo, así que es opt-in.
  [[ "$HOME" == "$ZELLIJ_LAYOUT_HOME" ]] && return 0
  layouts="$(grep -l "file:$ZELLIJ_LAYOUT_HOME/" "$DOTFILES"/zellij/layouts/*.kdl 2>/dev/null)"
  [[ -z "$layouts" ]] && return 0
  log_warn "Los layouts apuntan a $ZELLIJ_LAYOUT_HOME y tu HOME es $HOME"
  if [[ "$DRY_RUN" == 1 ]]; then
    log_info "Se ofrecería reescribir: $(echo $layouts | xargs -n1 basename | tr '\n' ' ')"
    return 0
  fi
  if [[ "$ASSUME_YES" == 1 ]] || ! gum confirm --default=false "¿Reescribir rutas de los layouts a $HOME? (modifica ficheros del repo)"; then
    log_info "Sin cambios. Los plugins zjstatus no cargarán hasta ajustar las rutas"
    return 0
  fi
  for f in $layouts; do
    run sed -i.bak "s|file:$ZELLIJ_LAYOUT_HOME/|file:$HOME/|g" "$f"
    run rm -f "$f.bak"
  done
  log_ok "Rutas de layouts actualizadas a $HOME"
}
