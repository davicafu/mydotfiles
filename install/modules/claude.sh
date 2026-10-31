# Skills personales para agentes de IA (claude/skills) e instrucciones
# globales (claude/CLAUDE.md), para todos los repos.
#
# Skills: mismo layout que `npx skills add -g`. Cada una se copia a
# ~/.agents/skills/<skill> (opencode y el resto de agentes) y se enlaza desde
# ~/.claude/skills/<skill> (Claude Code). Se copian una vez y no se refrescan,
# como la config de opencode: lo que cambies en la máquina se pasa al repo a
# mano. Si la skill ya está en la máquina, se deja como está.
#
# ~/.claude/CLAUDE.md es de cada máquina: solo se le añade una línea que
# importa el del repo, y lo de cada trabajo se queda en ese fichero.
#
# Las skills de Matt Pocock no van en el repo: en Claude Code se instalan como
# plugin (se actualiza solo) y en opencode, que no tiene plugins, con el CLI
# de skills.sh, solo si se acepta.

CLAUDE_MD="$HOME/.claude/CLAUDE.md"
CLAUDE_IMPORT="@$DOTFILES/claude/CLAUDE.md"
MATTPOCOCK_PLUGIN="mattpocock-skills@claude-plugins-official"

claude_desc() { echo "Skills personales y CLAUDE.md global para agentes de IA"; }
claude_supported() { return 0; }
claude_default() { return 0; }

claude_skills() {
  local d
  for d in "$DOTFILES"/claude/skills/*/; do
    basename "$d"
  done
}

# Instalada si Claude Code la encuentra, venga de donde venga
claude_skill_ok() { [[ -f "$HOME/.claude/skills/$1/SKILL.md" ]]; }

claude_md_ok() { [[ -f "$CLAUDE_MD" ]] && grep -qxF "$CLAUDE_IMPORT" "$CLAUDE_MD"; }

claude_status() {
  local s states=""
  for s in $(claude_skills); do
    states="$states $(status_of claude_skill_ok "$s")"
  done
  # shellcheck disable=SC2086
  combine_status $states "$(status_of claude_md_ok)"
}

claude_install_skill() {
  local s="$1" agents="$HOME/.agents/skills/$1" link="$HOME/.claude/skills/$1"
  if claude_skill_ok "$s"; then
    log_skip "Skill $s ya instalada"
    return 0
  fi
  if [[ -e "$agents" || -L "$agents" ]]; then
    log_skip "$agents ya existe"
  else
    run mkdir -p "$(dirname "$agents")"
    run cp -R "$DOTFILES/claude/skills/$s" "$agents"
    log_ok "Copiada $agents"
  fi
  # Si en ~/.claude/skills hay algo roto, se aparta fuera de la carpeta de
  # skills: un *.backup-<fecha> al lado se cargaría como skill duplicada.
  if [[ -e "$link" || -L "$link" ]]; then
    if ! confirm "$link no tiene un SKILL.md válido. ¿Hacer backup y reemplazar?"; then
      log_warn "Omitido $link"
      return 0
    fi
    run mkdir -p "$HOME/.cache/mydotfiles/skills-backup-$TIMESTAMP"
    run mv "$link" "$HOME/.cache/mydotfiles/skills-backup-$TIMESTAMP/"
    log_warn "Backup: $link → ~/.cache/mydotfiles/skills-backup-$TIMESTAMP/"
  fi
  run mkdir -p "$(dirname "$link")"
  run ln -s "../../.agents/skills/$s" "$link"
  log_ok "$link → ~/.agents/skills/$s"
}

claude_mattpocock() {
  local plugins="$HOME/.claude/plugins/installed_plugins.json"
  local cmd="npx skills@latest add mattpocock/skills -g -a opencode"
  if [[ -f "$plugins" ]] && grep -F "\"$MATTPOCOCK_PLUGIN\"" "$plugins" >/dev/null; then
    log_skip "Skills de Matt Pocock ya instaladas en Claude Code"
  else
    log_info "Skills de Matt Pocock en Claude Code: claude plugin install $MATTPOCOCK_PLUGIN"
  fi

  # opencode no tiene plugins: se copian con skills.sh, solo si se acepta
  has opencode || return 0
  if [[ -f "$HOME/.agents/skills/codebase-design/SKILL.md" ]]; then
    log_skip "Skills de Matt Pocock ya instaladas para opencode"
  elif [[ "$ASSUME_YES" == 1 || "$DRY_RUN" == 1 ]] || ! has npx; then
    log_info "Skills de Matt Pocock en opencode (opcional, necesita Node): $cmd"
  elif gum confirm --default=false "¿Instalar las skills de Matt Pocock para opencode? (se actualizan a mano con npx skills update)"; then
    run npx skills@latest add mattpocock/skills -g -a opencode
  else
    log_info "Para instalarlas más adelante: $cmd"
  fi
}

claude_install() {
  local s
  for s in $(claude_skills); do
    claude_install_skill "$s"
  done
  run mkdir -p "$(dirname "$CLAUDE_MD")"
  ensure_line "$CLAUDE_MD" "$CLAUDE_IMPORT"
  claude_mattpocock
}
