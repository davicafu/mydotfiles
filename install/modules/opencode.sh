# opencode: agentes, skills, comandos y prompts
#
# Dos variantes de ~/.config/opencode (OPENCODE_VARIANT o --opencode):
#   repo    copia de la config del repo (por defecto). Es una carpeta de la
#           máquina: lo que escriban opencode, Orca, engram o gentle-ai se
#           queda ahí y no llega al repo. Los cambios se pasan al repo a mano.
#   limpia  sin config: opencode arranca con sus valores por defecto
# Se puede cambiar de una a otra volviendo a ejecutar el instalador. Los datos
# de opencode (login, sesiones) no se tocan al cambiar. Si ~/.config/opencode
# es un enlace al repo (layout antiguo), se pasa a una copia.

# Marcas que dejan las variantes para reconocerlas en siguientes ejecuciones
OPENCODE_REPO_MARKER=".mydotfiles-repo"
OPENCODE_CLEAN_MARKER=".mydotfiles-limpia"
# Lo que no se copia del repo: estado de la máquina que opencode escribía en
# el repo con el layout antiguo, y restos
OPENCODE_STATE="cli.json service.json"
OPENCODE_EXCLUDES=(./cli.json ./service.json node_modules ".mydotfiles-*" "*.backup-*")

opencode_desc() {
  local current
  current="$(opencode_current_variant)"
  case "$current" in
    repo | limpia | enlace) echo "opencode con skills · comandos SDD y perfiles (actual: $current)" ;;
    *) echo "opencode con skills · comandos SDD y perfiles" ;;
  esac
}
opencode_supported() { return 0; }
opencode_default() { return 1; }

opencode_config() { echo "$CONFIG_DIR/opencode"; }

# Variante instalada ahora: repo | limpia | enlace | otra | ninguna
opencode_current_variant() {
  local cfg
  cfg="$(opencode_config)"
  if [[ "$(link_status "$DOTFILES/opencode" "$cfg")" == ok ]]; then
    echo enlace
  elif [[ -f "$cfg/$OPENCODE_REPO_MARKER" ]]; then
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
    ninguna | enlace) config=pending ;;
    *) config=conflict ;;
  esac
  # La config del repo usa engram (plugin + MCP)
  if [[ "$(opencode_target_variant)" == repo ]]; then
    combine_status "$(status_of brew_satisfied opencode)" "$(status_of brew_satisfied engram)" "$config"
  else
    combine_status "$(status_of brew_satisfied opencode)" "$config"
  fi
}

# Copia opencode/ del repo a cfg, sin el estado de la máquina ni restos.
opencode_copy_repo() {
  local cfg="$1" x
  local excludes=()
  for x in "${OPENCODE_EXCLUDES[@]}"; do excludes+=("--exclude=$x"); done
  run mkdir -p "$cfg"
  run sh -c 'src=$1 dst=$2; shift 2; tar -C "$src" -cf - "$@" . | tar -C "$dst" -xpf -' \
    sh "$DOTFILES/opencode" "$cfg" "${excludes[@]}"
  run touch "$cfg/$OPENCODE_REPO_MARKER"
  log_ok "Config del repo copiada a $cfg"
  log_info "Los cambios en $cfg no van al repo: para guardarlos, cópialos a mano a $DOTFILES/opencode"
}

# Con el layout antiguo opencode guardaba su estado (cli.json, service.json)
# dentro del repo: se lleva a la nueva carpeta.
opencode_move_state() {
  local cfg="$1" f
  for f in $OPENCODE_STATE; do
    [[ -f "$DOTFILES/opencode/$f" ]] || continue
    run mv "$DOTFILES/opencode/$f" "$cfg/$f"
    log_ok "$f movido del repo a $cfg"
  done
}

opencode_install() {
  local target current cfg migrate=0
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

  if [[ "$current" == enlace ]]; then
    # Quitar el enlace no pierde nada: la config sigue en el repo
    log_warn "$cfg es un enlace al repo (layout antiguo): se pasa a una copia"
    backup "$cfg"
    current=ninguna
    if [[ "$target" == repo ]]; then migrate=1; fi
  elif [[ "$current" != "$target" && "$current" != ninguna ]]; then
    if ! confirm "Hay una config de opencode ($current). ¿Hacer backup de ella y pasar a '$target'?"; then
      log_warn "Sin cambios en la config de opencode"
      return 0
    fi
    backup "$cfg"
    current=ninguna
  fi

  if [[ "$target" == repo ]]; then
    if [[ "$current" == repo ]]; then
      log_skip "opencode ya usa una copia de la config del repo en $cfg"
      log_info "No se actualiza desde el repo: para volver a copiarla, mueve $cfg y ejecuta otra vez"
    else
      opencode_copy_repo "$cfg"
      if [[ "$migrate" == 1 ]]; then opencode_move_state "$cfg"; fi
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
