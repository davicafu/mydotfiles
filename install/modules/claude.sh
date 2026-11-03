# Claude Code (agente de programación de Anthropic). Script oficial en todas
# las plataformas: instala en ~/.local y se actualiza solo. Al instalarlo se
# conecta a las skills e instrucciones globales (agents_setup, módulo agents).

claude_desc() { echo "Claude Code agente de programación de IA"; }
claude_supported() { return 0; }
claude_default() { return 0; }

# Puede estar instalado con brew (cask claude-code), npm o el script
claude_ok() { has claude || [[ -x "$HOME/.local/bin/claude" ]]; }

# Instalado pero sin conectar a las skills e instrucciones: parcial
claude_status() {
  if claude_ok; then agents_setup_status claude; else echo pending; fi
}

claude_install() {
  if claude_ok; then
    log_skip "Claude Code ya instalado"
  else
    run bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
    log_ok "Claude Code instalado en ~/.local/bin (inicia sesión con: claude)"
  fi
  agents_setup claude
}
