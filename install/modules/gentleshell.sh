# Gentle Shell (workspace de agentes de IA sobre pi, de gentle-ai). Lo instala
# `gentle-ai shell install`, un TUI propio que deja en ~/.gentle-shell su pi,
# gentle-ai fijado y Engram, y los lanzadores gentle-shell y gs en
# ~/.local/bin. No hay fórmula de brew ni un modo desatendido sencillo: con -y
# solo se muestra el comando. Se actualiza desde el mismo TUI. Una vez
# instalado se conecta a las skills e instrucciones globales (agents_setup).

gentleshell_desc() { echo "Gentle Shell workspace de agentes sobre pi y gentle-ai"; }
gentleshell_supported() { return 0; }
gentleshell_default() { return 1; }

gentleshell_ok() { has gentle-shell || [[ -x "$HOME/.local/bin/gentle-shell" ]]; }

gentleshell_status() {
  if gentleshell_ok; then agents_setup_status gentleshell; else echo pending; fi
}

gentleshell_install() {
  if gentleshell_ok; then
    log_skip "Gentle Shell ya instalado"
  else
    has gentle-ai || brew_bundle gentleai
    if [[ "$ASSUME_YES" == 1 || "$DRY_RUN" == 1 ]]; then
      log_warn "Gentle Shell se instala con su propio TUI: gentle-ai shell install"
    else
      # Sin run(): es un TUI y no se le redirige nada
      log_file "RUN   gentle-ai shell install"
      gentle-ai shell install
    fi
  fi
  # Su home aparece al instalar (o en el primer arranque)
  if gentleshell_ok || [[ -d "$HOME/.gentle-shell/agent" ]]; then
    agents_setup gentleshell
  fi
}
