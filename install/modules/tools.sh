# Herramientas CLI, elegibles una a una (paso "Herramientas" de la TUI o --tools).
# Las marcadas con 1 son las de siempre y vienen preseleccionadas; las 0 son
# opcionales. Varias las usa zsh/conf.d (aliases y funciones).

# id|fórmula de brew|plataformas (all o mac)|por defecto|descripción (sin comas)
TOOLS_CATALOG='eza|eza|all|1|ls moderno con iconos y vista de árbol (ls · ll · la · lt)
bat|bat|all|1|cat con resaltado de sintaxis (alias cat)
fzf|fzf|all|1|buscador difuso interactivo (cdf · ff · fg · fkill)
fd|fd|all|1|find rápido y simple (alias find)
ripgrep|ripgrep|all|1|grep muy rápido que respeta .gitignore (alias grep)
zoxide|zoxide|all|1|cd que recuerda tus carpetas (z carpeta)
atuin|atuin|all|1|historial de comandos con búsqueda (Ctrl-R)
btop|btop|all|1|monitor de CPU · RAM · disco y procesos
mole|mole|mac|0|limpieza y optimización del Mac
hazelnut|ricardodantas/tap/hazelnut|all|0|organizador automático de ficheros
croc|croc|all|0|envía ficheros entre equipos con un código
toilet|toilet|all|0|banners de texto grandes en la terminal
asciinema|asciinema|all|0|graba sesiones de terminal
pandoc|pandoc|all|0|conversor de documentos (md · docx · pdf · html)
chafa|chafa|all|0|muestra imágenes en la terminal'

# Herramientas que usan los aliases y funciones de zsh/conf.d
TOOLS_USED_BY_ZSH="eza bat fzf fd ripgrep zoxide atuin"

tools_desc() { echo "Herramientas CLI (eza · bat · fzf · rg · zoxide · atuin...)"; }
tools_supported() { return 0; }
tools_default() { return 0; }

# Líneas del catálogo disponibles en el SO destino.
tools_catalog() {
  local id formula os def desc
  while IFS='|' read -r id formula os def desc; do
    [[ "$os" == all || "$os" == "$(os_kind)" ]] || continue
    echo "$id|$formula|$def|$desc"
  done <<<"$TOOLS_CATALOG"
}

tools_field() {
  tools_catalog | awk -F'|' -v id="$1" -v f="$2" '$1 == id {print $f}'
}

tools_defaults() { tools_catalog | awk -F'|' '$3 == 1 {print $1}'; }

# Elegidas en la TUI o con --tools; si no, las de por defecto.
tools_selected() {
  if [[ "${TOOLS_SET:-0}" == 1 ]]; then
    echo $TOOLS_SELECTED | tr ' ' '\n' | sed '/^$/d'
  else
    tools_defaults
  fi
}

# Fórmulas instaladas (nombre corto). brew list es lento: se guarda en
# TOOLS_INSTALLED en el shell actual para que las subshells lo hereden.
tools_prime_cache() {
  TOOLS_INSTALLED=" $(brew list --formula -1 2>/dev/null | tr '\n' ' ') "
}

tools_brew_list() {
  [[ -n "${TOOLS_INSTALLED:-}" ]] || tools_prime_cache
  echo "$TOOLS_INSTALLED"
}

tools_is_installed() {
  local formula
  formula="$(tools_field "$1" 2)"
  [[ "$(tools_brew_list)" == *" ${formula##*/} "* ]]
}

tools_status() {
  local id statuses=""
  tools_prime_cache
  for id in $(tools_selected); do
    statuses="$statuses $(status_of tools_is_installed "$id")"
  done
  [[ -z "$statuses" ]] && echo ok && return
  combine_status $statuses
}

# Brewfile con las herramientas pedidas (con su tap si es de terceros).
tools_brewfile() {
  local id formula
  for id in "$@"; do
    formula="$(tools_field "$id" 2)"
    [[ "$formula" == */*/* ]] && echo "tap \"${formula%/*}\""
    echo "brew \"$formula\""
  done
}

tools_install() {
  local selected="" id missing="" file
  tools_prime_cache
  for id in $(tools_selected); do
    if [[ -z "$(tools_field "$id" 1)" ]]; then
      log_warn "Herramienta desconocida o no disponible en $(os_kind): $id"
    else
      selected="$selected $id"
    fi
  done
  if [[ -z "${selected// /}" ]]; then
    log_skip "Ninguna herramienta seleccionada"
  else
    for id in $selected; do
      tools_is_installed "$id" || missing="$missing $id"
    done
    if [[ -z "$missing" ]]; then
      log_skip "Ya instaladas:$(printf ' %s' $selected)"
    else
      file="$(mktemp)"
      tools_brewfile $missing >"$file"
      log_info "Instalando:$missing"
      if [[ "$DRY_RUN" == 1 ]]; then
        sed 's/^/  [dry-run] /' "$file"
      else
        run brew bundle install --no-upgrade --file="$file"
        log_ok "Instaladas:$missing"
        tools_prime_cache
      fi
      rm -f "$file"
    fi
  fi

  # Avisa si zsh usa alguna que no está ni elegida ni instalada
  for id in $TOOLS_USED_BY_ZSH; do
    [[ " $selected " == *" $id "* ]] && continue
    tools_is_installed "$id" ||
      log_warn "$id no está instalada y zsh la usa: $(tools_field "$id" 4)"
  done
}
