# zsh y sus plugins. Las herramientas CLI van en el módulo tools.
#
# ~/.zshrc es un fichero de cada máquina, no un enlace al repo. Su primera
# línea carga la config del repo (zsh/zshrc) y debajo queda lo que añadan
# otros instaladores (mise, factorial-dev...), que se ejecuta después. Así el
# repo nunca se modifica al instalar otras herramientas.

ZSHRC="$HOME/.zshrc"
# Layout antiguo: zsh/ enlazado como ZDOTDIR
ZDOTDIR_LINE='export ZDOTDIR="$HOME/.config/zsh"'
ZSH_LEGACY_LINK="$CONFIG_DIR/zsh"

zsh_desc() { echo "zsh · autosuggestions · syntax-highlighting · completions"; }
zsh_supported() { return 0; }
zsh_default() { return 0; }

# Ruta del repo con $HOME sin expandir, para que ~/.zshrc sea legible.
zsh_loader_line() {
  local path="$DOTFILES/zsh/zshrc"
  [[ "$path" == "$HOME/"* ]] && path="\$HOME/${path#"$HOME/"}"
  echo "source \"$path\""
}

zsh_stub_ok() {
  [[ -f "$ZSHRC" && ! -L "$ZSHRC" ]] && grep -xF "$(zsh_loader_line)" "$ZSHRC" >/dev/null
}

zsh_legacy() {
  local f
  [[ -L "$ZSH_LEGACY_LINK" ]] && return 0
  [[ -f "$HOME/.zshenv" ]] && grep -xF "$ZDOTDIR_LINE" "$HOME/.zshenv" >/dev/null && return 0
  # Enlaces que apuntaban dentro del layout antiguo (incluidos los rotos)
  for f in "$HOME/.zshenv" "$HOME/.zprofile" "$HOME/.zlogin"; do
    [[ -L "$f" ]] && case "$(readlink "$f")" in "$ZSH_LEGACY_LINK"/* | "$DOTFILES/zsh"/*) return 0 ;; esac
  done
  return 1
}

zsh_is_login_shell() { [[ "$(basename "${SHELL:-}")" == zsh ]]; }

zsh_status() {
  local legacy=ok
  zsh_legacy && legacy=conflict
  combine_status \
    "$(status_of brew_satisfied zsh)" \
    "$(status_of zsh_stub_ok)" \
    "$legacy" \
    "$(status_of zsh_is_login_shell)"
}

# ── Migración del layout con ZDOTDIR ─────────────────────────────────────────

# Ficheros que zsh y otros instaladores dejaron dentro de zsh/ del repo.
ZSH_REPO_LEFTOVERS=".zshenv .zprofile .zshrc.pre-oh-my-zsh ohmyzsh .zsh_sessions"

# Convierte ~/.zshenv, ~/.zprofile... en ficheros normales si son enlaces
# (normalmente al repo): su contenido es de esta máquina y el destino se va a
# mover. Sin esto, editar el fichero editaría el repo a través del enlace.
zsh_materialize_links() {
  local f content
  for f in "$HOME/.zshenv" "$HOME/.zprofile" "$HOME/.zlogin"; do
    [[ -L "$f" ]] || continue
    content="$(cat "$f" 2>/dev/null)"
    backup "$f"
    if [[ -n "$content" ]]; then
      if [[ "$DRY_RUN" == 1 ]]; then
        run "escribir $f con el contenido de su enlace"
      else
        printf '%s\n' "$content" >"$f"
      fi
      log_ok "$f pasa a ser un fichero de esta máquina"
    fi
  done
}

zsh_migrate_legacy() {
  local f moved=0 dest
  zsh_legacy || return 0
  log_warn "Detectado el layout antiguo (ZDOTDIR → $DOTFILES/zsh)"
  confirm "¿Migrar al nuevo ~/.zshrc? (se hace backup de todo lo que se mueve)" || return 1

  zsh_materialize_links

  # ~/.zshenv: solo se quita la línea de ZDOTDIR, el resto se queda
  if [[ -f "$HOME/.zshenv" ]] && grep -xF "$ZDOTDIR_LINE" "$HOME/.zshenv" >/dev/null; then
    remove_line "$HOME/.zshenv" "$ZDOTDIR_LINE"
  fi

  [[ -L "$ZSH_LEGACY_LINK" ]] && backup "$ZSH_LEGACY_LINK"

  # El historial vivía en el repo: se añade al de ~/.zsh_history
  if [[ -s "$DOTFILES/zsh/.zsh_history" ]]; then
    [[ -f "$HOME/.zsh_history" ]] && run cp -p "$HOME/.zsh_history" "$HOME/.zsh_history.backup-$TIMESTAMP"
    if [[ "$DRY_RUN" == 1 ]]; then
      run "cat $DOTFILES/zsh/.zsh_history >> $HOME/.zsh_history"
    else
      cat "$DOTFILES/zsh/.zsh_history" >>"$HOME/.zsh_history"
      chmod 600 "$HOME/.zsh_history"
    fi
    log_ok "Historial del repo añadido a ~/.zsh_history"
  fi

  # Restos dentro del repo: fuera, a una carpeta de backup
  dest="${XDG_STATE_HOME:-$HOME/.local/state}/mydotfiles/zsh-legacy-$TIMESTAMP"
  for f in $ZSH_REPO_LEFTOVERS .zsh_history $(cd "$DOTFILES/zsh" && ls -d .zcompdump* 2>/dev/null); do
    [[ -e "$DOTFILES/zsh/$f" ]] || continue
    run mkdir -p "$dest"
    run mv "$DOTFILES/zsh/$f" "$dest/"
    moved=1
  done
  [[ $moved == 1 ]] && log_ok "Restos del layout antiguo movidos a $dest"
  return 0
}

# ── ~/.zshrc ─────────────────────────────────────────────────────────────────

zsh_stub_header() {
  cat <<EOF
# Config de zsh de mydotfiles: se carga primero.
$(zsh_loader_line)

# ── Esta máquina ─────────────────────────────────────────────────────────────
# Lo que añadan otros instaladores va aquí debajo y se ejecuta después del repo.
EOF
}

zsh_write_stub() {
  local tmp
  if zsh_stub_ok; then
    log_skip "~/.zshrc ya carga la config del repo"
    return 0
  fi
  tmp="$(mktemp)"
  zsh_stub_header >"$tmp"

  if [[ -L "$ZSHRC" ]]; then
    # Enlace (al repo u otro sitio): se aparta, no hay contenido local que guardar
    backup "$ZSHRC"
  elif [[ -f "$ZSHRC" ]]; then
    # Fichero con contenido de esta máquina: se conserva debajo del repo
    confirm "~/.zshrc ya existe. ¿Hacer backup y cargar el repo antes de su contenido?" || {
      rm -f "$tmp"
      return 1
    }
    run cp -p "$ZSHRC" "$ZSHRC.backup-$TIMESTAMP"
    log_warn "Backup: $ZSHRC → $ZSHRC.backup-$TIMESTAMP"
    cat "$ZSHRC" >>"$tmp"
    log_info "El contenido anterior de ~/.zshrc queda debajo de la config del repo"
  fi

  if [[ "$DRY_RUN" == 1 ]]; then
    run "escribir ~/.zshrc con: $(zsh_loader_line)"
  else
    mv "$tmp" "$ZSHRC"
  fi
  rm -f "$tmp"
  log_ok "~/.zshrc carga $DOTFILES/zsh/zshrc"
}

# ── Resto ────────────────────────────────────────────────────────────────────

zsh_set_login_shell() {
  local zsh_path
  if zsh_is_login_shell; then
    log_skip "zsh ya es la shell por defecto"
    return 0
  fi
  zsh_path="$(command -v zsh)"
  confirm "¿Usar $zsh_path como shell por defecto?" || return 0
  if ! grep -xF "$zsh_path" /etc/shells >/dev/null; then
    run sudo sh -c "echo '$zsh_path' >> /etc/shells"
  fi
  run chsh -s "$zsh_path"
  log_ok "Shell por defecto: $zsh_path (efectivo en el próximo login)"
}

# Importa el historial existente en atuin solo la primera vez.
zsh_import_history() {
  if ! has atuin; then
    log_skip "atuin no instalado: no hay historial que importar"
    return 0
  fi
  if [[ -f "$HOME/.local/share/atuin/history.db" ]]; then
    log_skip "atuin ya inicializado"
    return 0
  fi
  if [[ ! -s "$HOME/.zsh_history" ]]; then
    log_skip "Sin historial de zsh que importar en atuin"
    return 0
  fi
  if run env HISTFILE="$HOME/.zsh_history" atuin import zsh >/dev/null; then
    log_ok "Historial importado en atuin"
  else
    log_warn "No se pudo importar el historial en atuin"
  fi
}

zsh_install() {
  brew_bundle zsh
  zsh_migrate_legacy || {
    log_warn "Sin migrar: ~/.zshrc no se modifica"
    return 0
  }
  zsh_write_stub || return 0
  zsh_import_history
  zsh_set_login_shell
  brew_satisfied p10k || log_warn "powerlevel10k no está instalado: el prompt será el de zsh"
}
