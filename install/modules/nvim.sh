# Neovim (LazyVim) + formatters
#
# Dos variantes de ~/.config/nvim (NVIM_VARIANT o --nvim):
#   repo    symlink a la config del repo, plugins según lazy-lock.json (por defecto)
#   limpia  LazyVim starter sin personalizar
# Se puede cambiar de una a otra volviendo a ejecutar el instalador.

NVIM_STARTER="https://github.com/LazyVim/starter"
# Marca que deja la variante limpia para reconocerla en siguientes ejecuciones
NVIM_CLEAN_MARKER=".mydotfiles-limpia"

nvim_desc() {
  local current
  current="$(nvim_current_variant)"
  case "$current" in
    repo | limpia) echo "Neovim con LazyVim (actual: $current)" ;;
    *) echo "Neovim con LazyVim" ;;
  esac
}
nvim_supported() { return 0; }
nvim_default() { return 0; }

nvim_config() { echo "$CONFIG_DIR/nvim"; }
nvim_data_dirs() {
  echo "${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
  echo "${XDG_STATE_HOME:-$HOME/.local/state}/nvim"
  echo "${XDG_CACHE_HOME:-$HOME/.cache}/nvim"
}

# Variante instalada ahora: repo | limpia | otra | ninguna
nvim_current_variant() {
  local cfg
  cfg="$(nvim_config)"
  if [[ "$(link_status "$DOTFILES/nvim" "$cfg")" == ok ]]; then
    echo repo
  elif [[ -f "$cfg/$NVIM_CLEAN_MARKER" ]]; then
    echo limpia
  elif [[ -e "$cfg" || -L "$cfg" ]]; then
    echo otra
  else
    echo ninguna
  fi
}

# Variante para --status: la pedida o, si no, la que ya haya (así una
# instalación limpia no sale como conflicto).
nvim_target_variant() {
  if [[ -n "${NVIM_VARIANT:-}" ]]; then
    echo "$NVIM_VARIANT"
  elif [[ "$(nvim_current_variant)" == limpia ]]; then
    echo limpia
  else
    echo repo
  fi
}

nvim_kdlfmt_ok() { has kdlfmt || [[ -x "$HOME/.cargo/bin/kdlfmt" ]]; }
nvim_plugins_ok() { [[ -d "$(nvim_data_dirs | head -n 1)/lazy/lazy.nvim" ]]; }

# Como nvim_plugins_ok, pero en dry-run tras un backup (que no se hizo de
# verdad) cuenta los plugins como apartados.
nvim_plugins_present() {
  [[ "$DRY_RUN" == 1 && "${NVIM_BACKED_UP:-0}" == 1 ]] && return 1
  nvim_plugins_ok
}

nvim_status() {
  local config
  case "$(nvim_current_variant)" in
    "$(nvim_target_variant)") config=ok ;;
    ninguna) config=pending ;;
    *) config=conflict ;;
  esac
  if [[ "$(nvim_target_variant)" == repo ]]; then
    combine_status \
      "$(status_of brew_satisfied nvim)" "$config" \
      "$(status_of nvim_kdlfmt_ok)" "$(status_of nvim_plugins_ok)"
  else
    combine_status \
      "$(status_of brew_satisfied nvim)" "$config" "$(status_of nvim_plugins_ok)"
  fi
}

# Aparta la config actual y los datos de nvim (plugins, Mason, estado, caché)
# a *.backup-<fecha>. Así la variante nueva arranca de cero y nada se pierde.
nvim_backup_current() {
  local current="$1" target="$2" dir
  confirm "Hay una config de nvim ($current). ¿Hacer backup de ella y de sus datos y pasar a '$target'?" ||
    return 1
  backup "$(nvim_config)"
  for dir in $(nvim_data_dirs); do
    [[ -e "$dir" ]] && backup "$dir"
  done
  return 0
}

# Ejecuta Lazy en headless. nvim sale con 0 aunque falle la carga de la
# config, así que se comprueba a mano que lazy.nvim quedó instalado.
nvim_lazy() {
  local title="$1" cmd="$2"
  if [[ "$DRY_RUN" == 1 ]]; then
    run nvim --headless "+Lazy! $cmd" +qa
    return 0
  fi
  gum spin --title "$title" --show-error -- nvim --headless "+Lazy! $cmd" +qa || true
}

# Instala los plugins en las versiones de lazy-lock.json. En el primer
# arranque lazy instala lo que falta y reescribe el lockfile (que es un
# fichero del repo vía symlink), así que se guarda y se repone.
nvim_restore_plugins() {
  local lock="$DOTFILES/nvim/lazy-lock.json" saved
  if nvim_plugins_present; then
    log_skip "Plugins de nvim ya instalados"
    return 0
  fi
  [[ "$DRY_RUN" == 1 ]] && nvim_lazy "" restore && return 0
  saved="$(mktemp)"
  cp "$lock" "$saved"
  nvim_lazy "Instalando plugins de nvim..." restore
  cp "$saved" "$lock"
  nvim_lazy "Fijando versiones de lazy-lock.json..." restore
  cp "$saved" "$lock"
  rm -f "$saved"
  if ! nvim_plugins_ok; then
    log_err "No se instalaron los plugins. Abre nvim para ver el error"
    return 1
  fi
  log_ok "Plugins de nvim instalados según lazy-lock.json"
}

nvim_install_repo() {
  if nvim_kdlfmt_ok; then
    log_skip "kdlfmt ya instalado"
  else
    run cargo install kdlfmt
    log_ok "kdlfmt instalado"
  fi
  case ":$PATH:" in
    *":$HOME/.cargo/bin:"*) ;;
    *) log_warn "~/.cargo/bin no está en el PATH: conform no encontrará kdlfmt" ;;
  esac

  if [[ "$DRY_RUN" == 1 && "${NVIM_BACKED_UP:-0}" == 1 ]]; then
    # En dry-run el backup no se hizo de verdad: link volvería a verlo
    run ln -s "$DOTFILES/nvim" "$(nvim_config)"
  else
    link "$DOTFILES/nvim" "$(nvim_config)"
  fi
  nvim_restore_plugins
  log_info "Para resincronizar más adelante: :Lazy restore"
}

nvim_install_clean() {
  local cfg
  cfg="$(nvim_config)"
  if [[ "$(nvim_current_variant)" == limpia ]]; then
    log_skip "LazyVim starter ya instalado en $cfg"
  else
    run git clone --depth 1 "$NVIM_STARTER" "$cfg"
    run rm -rf "$cfg/.git"
    run touch "$cfg/$NVIM_CLEAN_MARKER"
    log_ok "LazyVim starter instalado en $cfg"
  fi

  if nvim_plugins_present; then
    log_skip "Plugins de nvim ya instalados"
  else
    nvim_lazy "Instalando plugins de LazyVim..." sync
    if [[ "$DRY_RUN" != 1 ]] && ! nvim_plugins_ok; then
      log_err "No se instalaron los plugins. Abre nvim para ver el error"
      return 1
    fi
    log_ok "Plugins de LazyVim instalados"
  fi
  log_info "Para pasar a la config del repo: ./install.sh --nvim repo nvim"
}

nvim_install() {
  local target current
  # Al instalar, sin --nvim se usa siempre la del repo
  target="${NVIM_VARIANT:-repo}"
  current="$(nvim_current_variant)"
  case "$target" in
    repo | limpia) ;;
    *)
      log_err "Variante de nvim no válida: $target (repo | limpia)"
      return 1
      ;;
  esac
  log_info "Variante: $target"

  brew_bundle nvim

  if [[ "$current" != "$target" && "$current" != ninguna ]]; then
    if ! nvim_backup_current "$current" "$target"; then
      log_warn "Sin cambios en la config de nvim"
      return 0
    fi
    NVIM_BACKED_UP=1
  fi

  [[ "$(os_kind)" == wsl ]] && install_win32yank

  if [[ "$target" == repo ]]; then
    nvim_install_repo
  else
    nvim_install_clean
  fi

  has node || log_warn "Node.js no encontrado: copilot lo necesita (p. ej. brew install node)"
}
