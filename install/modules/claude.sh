# Claude Code (agente de programación de Anthropic). Script oficial en todas
# las plataformas: instala en ~/.local y se actualiza solo. Al instalarlo se
# conecta a las skills e instrucciones globales (agents_setup, módulo agents)
# y a la barra de estado de claude/statusline.sh (modelo, effort, contexto y uso).

claude_desc() { echo "Claude Code agente de programación de IA"; }
claude_supported() { return 0; }
claude_default() { return 0; }

CLAUDE_STATUSLINE_SRC="$DOTFILES/claude/statusline.sh"
CLAUDE_STATUSLINE="$HOME/.claude/statusline.sh"
CLAUDE_STATUSLINE_CMD="~/.claude/statusline.sh"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

# Puede estar instalado con brew (cask claude-code), npm o el script
claude_ok() { has claude || [[ -x "$HOME/.local/bin/claude" ]]; }

# settings.json es de la máquina (lo escriben Claude Code, Orca...): no se
# enlaza, solo se le pone statusLine con jq sin tocar el resto.
claude_statusline_cmd() { jq -r '.statusLine.command // empty' "$CLAUDE_SETTINGS" 2>/dev/null; }
claude_statusline_set() { has jq && [[ "$(claude_statusline_cmd)" == "$CLAUDE_STATUSLINE_CMD" ]]; }

claude_statusline_status() {
  combine_status \
    "$(status_of brew_satisfied claude)" \
    "$(link_status "$CLAUDE_STATUSLINE_SRC" "$CLAUDE_STATUSLINE")" \
    "$(status_of claude_statusline_set)"
}

claude_statusline_install() {
  local current tmp
  brew_bundle claude
  link "$CLAUDE_STATUSLINE_SRC" "$CLAUDE_STATUSLINE"
  if claude_statusline_set; then
    log_skip "statusLine de Claude Code ya configurada"
    return 0
  fi
  if ! has jq && [[ "$DRY_RUN" != 1 ]]; then
    log_warn "Falta jq: no se configura la statusLine de Claude Code"
    return 0
  fi
  current="$(claude_statusline_cmd)"
  if [[ -n "$current" ]] && ! confirm "~/.claude/settings.json ya tiene otra statusLine. ¿Reemplazarla por la del repo?"; then
    log_warn "statusLine de Claude Code sin cambiar"
    return 0
  fi
  run mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
  [[ -f "$CLAUDE_SETTINGS" ]] || run sh -c "echo '{}' > \"$CLAUDE_SETTINGS\""
  [[ -f "$CLAUDE_SETTINGS" ]] && run cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.backup-$TIMESTAMP"
  tmp="$CLAUDE_SETTINGS.tmp-$TIMESTAMP"
  run sh -c "jq --arg c '$CLAUDE_STATUSLINE_CMD' '.statusLine = {type: \"command\", command: \$c}' \"$CLAUDE_SETTINGS\" > \"$tmp\" && mv \"$tmp\" \"$CLAUDE_SETTINGS\""
  log_ok "statusLine de Claude Code → $CLAUDE_STATUSLINE_CMD (backup en settings.json.backup-$TIMESTAMP)"
}

# Instalado pero sin conectar a las skills, instrucciones o barra de estado: parcial
claude_status() {
  if claude_ok; then
    combine_status "$(agents_setup_status claude)" "$(claude_statusline_status)"
  else
    echo pending
  fi
}

claude_install() {
  if claude_ok; then
    log_skip "Claude Code ya instalado"
  else
    run bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
    log_ok "Claude Code instalado en ~/.local/bin (inicia sesión con: claude)"
  fi
  agents_setup claude
  claude_statusline_install
}
