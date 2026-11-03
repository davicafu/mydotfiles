# AI Agents: skills personales (agents/skills) e instrucciones globales
# (agents/AGENTS.md) para todos los repos y todos los agentes.
#
# Base común: cada skill se copia a ~/.agents/skills/<skill> (layout de
# `npx skills add -g`) y agents/AGENTS.md se enlaza en ~/.agents/AGENTS.md.
# Las skills se copian una vez y no se refrescan, como la config de opencode:
# lo que cambies en la máquina se pasa al repo a mano. AGENTS.md es un enlace:
# los cambios del repo llegan solos.
#
# Encima, cada agente se conecta a esa base a su manera (agents_setup):
#   claude       enlaza cada skill en ~/.claude/skills y añade una línea que
#                importa agents/AGENTS.md a ~/.claude/CLAUDE.md, que es de
#                cada máquina (Claude Code no lee AGENTS.md)
#   opencode     lee ~/.agents/skills y carga ~/.agents/AGENTS.md por
#                `instructions` en opencode.json (variante repo) o con
#                AGENTS.md enlazado en ~/.config/opencode (variante limpia)
#   pi           lee ~/.agents/skills; AGENTS.md enlazado en ~/.pi/agent
#   gentleshell  igual que pi, en ~/.gentle-shell/agent
# Los módulos claude, opencode y gentleshell lo hacen al instalarse; este
# módulo lo hace para todos los agentes que encuentre, también los que no
# instaló este repo. Un AGENTS.md que ya existe no se toca. El AGENTS.md de
# cada proyecto manda sobre estas instrucciones.
#
# Las skills de Matt Pocock no van en el repo: en Claude Code se instalan como
# plugin (se actualiza solo) y en opencode, que no tiene plugins, con el CLI
# de skills.sh, solo si se acepta.

AGENTS_MD="$DOTFILES/agents/AGENTS.md"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
CLAUDE_IMPORT="@$AGENTS_MD"
MATTPOCOCK_PLUGIN="mattpocock-skills@claude-plugins-official"
AGENTS_ALL="claude opencode pi gentleshell"

agents_desc() { echo "AI Agents skills e instrucciones para todos los agentes"; }
agents_supported() { return 0; }
agents_default() { return 0; }

agents_skills() {
  local d
  for d in "$DOTFILES"/agents/skills/*/; do
    basename "$d"
  done
}

# Agentes de la máquina. claude_ok y gentleshell_ok vienen de sus módulos y
# miran también ~/.local/bin, que justo tras instalar aún no está en el PATH.
agents_present() {
  case "$1" in
    claude) claude_ok || [[ -d "$HOME/.claude" ]] ;;
    opencode) has opencode || [[ -d "$CONFIG_DIR/opencode" ]] ;;
    pi) has pi || [[ -d "$HOME/.pi/agent" ]] ;;
    gentleshell) gentleshell_ok || [[ -d "$HOME/.gentle-shell/agent" ]] ;;
  esac
}

# ── Base común ───────────────────────────────────────────────────────────────

agents_base_status() {
  local s states=""
  for s in $(agents_skills); do
    states="$states $(status_of test -f "$HOME/.agents/skills/$s/SKILL.md")"
  done
  # shellcheck disable=SC2086
  combine_status $states "$(link_status "$AGENTS_MD" "$HOME/.agents/AGENTS.md")"
}

agents_base_install() {
  local s copy
  for s in $(agents_skills); do
    copy="$HOME/.agents/skills/$s"
    if [[ -e "$copy" || -L "$copy" ]]; then
      log_skip "$copy ya existe"
    else
      run mkdir -p "$(dirname "$copy")"
      run cp -R "$DOTFILES/agents/skills/$s" "$copy"
      log_ok "Copiada $copy"
    fi
  done
  agents_link_md "$HOME/.agents/AGENTS.md"
}

# Como link(), pero un AGENTS.md que ya existe es del usuario: no se reemplaza
agents_link_md() {
  local dst="$1"
  case "$(link_status "$AGENTS_MD" "$dst")" in
    ok) log_skip "$dst ya enlazado" ;;
    conflict) log_warn "$dst ya existe: no se toca (para usar el del repo, enlázalo a $AGENTS_MD)" ;;
    *)
      run mkdir -p "$(dirname "$dst")"
      run ln -s "$AGENTS_MD" "$dst"
      log_ok "$dst → $AGENTS_MD"
      ;;
  esac
}

# ── Claude Code ──────────────────────────────────────────────────────────────

agents_claude_md_ok() { [[ -f "$CLAUDE_MD" ]] && grep -qxF "$CLAUDE_IMPORT" "$CLAUDE_MD"; }

agents_claude_status() {
  local s states=""
  for s in $(agents_skills); do
    states="$states $(status_of test -f "$HOME/.claude/skills/$s/SKILL.md")"
  done
  # shellcheck disable=SC2086
  combine_status $states "$(status_of agents_claude_md_ok)"
}

agents_claude_install() {
  local s link plugins="$HOME/.claude/plugins/installed_plugins.json"
  for s in $(agents_skills); do
    link="$HOME/.claude/skills/$s"
    if [[ -f "$link/SKILL.md" ]]; then
      log_skip "Skill $s ya instalada en Claude Code"
      continue
    fi
    # Si hay algo roto, se aparta fuera de la carpeta de skills: un
    # *.backup-<fecha> al lado se cargaría como skill duplicada.
    if [[ -e "$link" || -L "$link" ]]; then
      if ! confirm "$link no tiene un SKILL.md válido. ¿Hacer backup y reemplazar?"; then
        log_warn "Omitido $link"
        continue
      fi
      run mkdir -p "$HOME/.cache/mydotfiles/skills-backup-$TIMESTAMP"
      run mv "$link" "$HOME/.cache/mydotfiles/skills-backup-$TIMESTAMP/"
      log_warn "Backup: $link → ~/.cache/mydotfiles/skills-backup-$TIMESTAMP/"
    fi
    run mkdir -p "$(dirname "$link")"
    run ln -s "../../.agents/skills/$s" "$link"
    log_ok "$link → ~/.agents/skills/$s"
  done
  run mkdir -p "$(dirname "$CLAUDE_MD")"
  ensure_line "$CLAUDE_MD" "$CLAUDE_IMPORT"
  if [[ -f "$plugins" ]] && grep -F "\"$MATTPOCOCK_PLUGIN\"" "$plugins" >/dev/null; then
    log_skip "Skills de Matt Pocock ya instaladas en Claude Code"
  else
    log_info "Skills de Matt Pocock en Claude Code: claude plugin install $MATTPOCOCK_PLUGIN"
  fi
}

# ── opencode ─────────────────────────────────────────────────────────────────

# Lee ~/.agents/skills tal cual. Las instrucciones las carga la variante repo
# con `instructions` en opencode.json; la limpia no tiene config, así que se
# le enlaza AGENTS.md (si no, opencode leería ~/.claude/CLAUDE.md con el @ sin
# resolver).
agents_opencode_md() {
  local cfg="$CONFIG_DIR/opencode"
  [[ -f "$cfg/$OPENCODE_CLEAN_MARKER" ]] && echo "$cfg/AGENTS.md"
  return 0
}

agents_opencode_status() {
  local md
  md="$(agents_opencode_md)"
  if [[ -n "$md" ]]; then link_status "$AGENTS_MD" "$md"; else echo ok; fi
}

agents_opencode_install() {
  local md cmd="npx skills@latest add mattpocock/skills -g -a opencode"
  md="$(agents_opencode_md)"
  if [[ -n "$md" ]]; then agents_link_md "$md"; fi
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

# ── pi y Gentle Shell ────────────────────────────────────────────────────────

agents_pi_md() {
  case "$1" in
    pi) echo "$HOME/.pi/agent/AGENTS.md" ;;
    gentleshell) echo "$HOME/.gentle-shell/agent/AGENTS.md" ;;
  esac
}

# ── Por agente ───────────────────────────────────────────────────────────────

# Estado de lo propio del agente, sin la base
agents_own_status() {
  case "$1" in
    claude) agents_claude_status ;;
    opencode) agents_opencode_status ;;
    pi | gentleshell) link_status "$AGENTS_MD" "$(agents_pi_md "$1")" ;;
  esac
}

agents_own_install() {
  case "$1" in
    claude) agents_claude_install ;;
    opencode) agents_opencode_install ;;
    pi | gentleshell) agents_link_md "$(agents_pi_md "$1")" ;;
  esac
}

# Base común + lo propio de un agente. Lo usan los módulos de cada agente.
agents_setup_status() { combine_status "$(agents_base_status)" "$(agents_own_status "$1")"; }

agents_setup() {
  agents_base_install
  agents_own_install "$1"
}

agents_status() {
  local a states
  states="$(agents_base_status)"
  for a in $AGENTS_ALL; do
    if agents_present "$a"; then states="$states $(agents_own_status "$a")"; fi
  done
  # shellcheck disable=SC2086
  combine_status $states
}

agents_install() {
  local a found=""
  agents_base_install
  for a in $AGENTS_ALL; do
    agents_present "$a" || continue
    found="$found $a"
    log_info "Agente: $a"
    agents_own_install "$a"
  done
  [[ -n "$found" ]] || log_info "No hay agentes instalados: solo la base en ~/.agents"
}
