# opencode: agentes, skills, comandos y prompts
#
# Dos variantes de ~/.config/opencode (OPENCODE_VARIANT o --opencode):
#   repo    symlink a la config del repo (por defecto)
#   limpia  sin config: opencode arranca con sus valores por defecto
# Se puede cambiar de una a otra volviendo a ejecutar el instalador. Los datos
# de opencode (login, sesiones) no se tocan al cambiar.

# Marca que deja la variante limpia para reconocerla en siguientes ejecuciones
OPENCODE_CLEAN_MARKER=".mydotfiles-limpia"

opencode_desc() {
  local current
  current="$(opencode_current_variant)"
  case "$current" in
    repo | limpia) echo "opencode con skills · comandos SDD y perfiles (actual: $current)" ;;
    *) echo "opencode con skills · comandos SDD y perfiles" ;;
  esac
}
opencode_supported() { return 0; }
opencode_default() { return 1; }

opencode_config() { echo "$CONFIG_DIR/opencode"; }

# Variante instalada ahora: repo | limpia | otra | ninguna
opencode_current_variant() {
  local cfg
  cfg="$(opencode_config)"
  if [[ "$(link_status "$DOTFILES/opencode" "$cfg")" == ok ]]; then
    echo repo
  elif [[ -f "$cfg/$OPENCODE_CLEAN_MARKER" ]]; then
    echo limpia
  elif [[ -e "$cfg" || -L "$cfg" ]]; then
    echo otra
  else
    echo ninguna
  fi
}

# Variante para --status: la pedida o, si no, la que ya haya.
opencode_target_variant() {
  if [[ -n "${OPENCODE_VARIANT:-}" ]]; then
    echo "$OPENCODE_VARIANT"
  elif [[ "$(opencode_current_variant)" == limpia ]]; then
    echo limpia
  else
    echo repo
  fi
}

opencode_status() {
  local config
  case "$(opencode_current_variant)" in
    "$(opencode_target_variant)") config=ok ;;
    ninguna) config=pending ;;
    *) config=conflict ;;
  esac
  # La config del repo usa engram (plugin + MCP)
  if [[ "$(opencode_target_variant)" == repo ]]; then
    combine_status "$(status_of brew_satisfied opencode)" "$(status_of brew_satisfied engram)" "$config"
  else
    combine_status "$(status_of brew_satisfied opencode)" "$config"
  fi
}

opencode_install() {
  local target current cfg
  # Al instalar, sin --opencode se usa siempre la del repo
  target="${OPENCODE_VARIANT:-repo}"
  current="$(opencode_current_variant)"
  cfg="$(opencode_config)"
  case "$target" in
    repo | limpia) ;;
    *)
      log_err "Variante de opencode no válida: $target (repo | limpia)"
      return 1
      ;;
  esac
  log_info "Variante: $target"

  brew_bundle opencode
  # La config del repo usa engram (plugin + MCP); la limpia no lo necesita
  if [[ "$target" == repo ]]; then
    brew_bundle engram
  fi

  if [[ "$current" != "$target" && "$current" != ninguna ]]; then
    if ! confirm "Hay una config de opencode ($current). ¿Hacer backup de ella y pasar a '$target'?"; then
      log_warn "Sin cambios en la config de opencode"
      return 0
    fi
    backup "$cfg"
    current=ninguna
  fi

  if [[ "$target" == repo ]]; then
    if [[ "$DRY_RUN" == 1 && "$current" == ninguna && -e "$cfg" ]]; then
      # En dry-run el backup no se hizo de verdad: link volvería a verlo
      run ln -s "$DOTFILES/opencode" "$cfg"
    else
      link "$DOTFILES/opencode" "$cfg"
    fi
  elif [[ "$current" == limpia ]]; then
    log_skip "opencode ya usa la config limpia en $cfg"
  else
    run mkdir -p "$cfg"
    run touch "$cfg/$OPENCODE_CLEAN_MARKER"
    log_ok "Config limpia de opencode en $cfg"
    log_info "Para pasar a la config del repo: ./install.sh --opencode repo opencode"
  fi
}
