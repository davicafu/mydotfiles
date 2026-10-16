#!/usr/bin/env bash
# Instalador idempotente de mydotfiles con TUI (gum).
# Se puede ejecutar tantas veces como se quiera: solo aplica lo que falta.

set -o pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES

# shellcheck source=install/lib.sh
source "$DOTFILES/install/lib.sh"
for f in "$DOTFILES"/install/modules/*.sh; do
  # shellcheck source=/dev/null
  source "$f"
done

# Orden de instalación
MODULES="font git tools zsh p10k tmux zellij nvim go ghostty wezterm opencode"

# Pasos de la TUI (elección única). "a+b" es una opción que instala ambos.
TERMINALS="ghostty wezterm"
SHELLS="zsh"
PROMPTS="p10k"
MULTIPLEXERS="tmux zellij tmux+zellij"
# Paso final (elección múltiple)
PACKAGES="font git nvim go opencode"

usage() {
  cat <<EOF
Uso: ./install.sh [opciones] [módulo...]

Sin argumentos abre la TUI para elegir módulos.

Opciones:
  -a, --all       Instala todos los módulos por defecto sin TUI
  -o, --os SO     SO destino: mac | linux | wsl (por defecto, el detectado)
      --nvim V    Variante de nvim: repo (por defecto) | limpia (LazyVim starter)
      --opencode V
                  Variante de opencode: repo (por defecto) | limpia (sin config)
      --tools L   Herramientas CLI separadas por comas (p. ej. eza,bat,fzf)
  -s, --status    Muestra el estado de cada módulo y sale
  -n, --dry-run   Muestra lo que haría sin cambiar nada
  -y, --yes       Responde que sí a todas las confirmaciones
  -h, --help      Muestra esta ayuda

Módulos: $MODULES
EOF
}

# ── Bootstrap: Homebrew + gum ────────────────────────────────────────────────

bootstrap() {
  local tool brew_bin
  for tool in git curl unzip; do
    if ! has "$tool"; then
      log_err "Falta '$tool'. En Debian/Ubuntu: sudo apt install -y build-essential git curl unzip"
      exit 1
    fi
  done

  if ! has brew; then
    for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
      [[ -x "$brew_bin" ]] && eval "$("$brew_bin" shellenv)" && break
    done
  fi
  if ! has brew; then
    printf 'Homebrew no está instalado. ¿Instalarlo ahora? [y/N] '
    read -r reply
    [[ "$reply" == [yYsS]* ]] || exit 1
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
      [[ -x "$brew_bin" ]] && eval "$("$brew_bin" shellenv)" && break
    done
  fi

  if ! has gum; then
    log_info "Instalando gum para la TUI..."
    brew bundle install --no-upgrade --file="$(brewfile bootstrap)" >/dev/null || exit 1
  fi
}

# ── Estado ───────────────────────────────────────────────────────────────────

supported_modules() {
  local m
  for m in $MODULES; do
    "${m}_supported" && echo "$m"
  done
}

status_label() {
  case "$1" in
    ok) echo "instalado" ;;
    partial) echo "parcial" ;;
    conflict) echo "conflicto" ;;
    *) echo "pendiente" ;;
  esac
}

status_color() {
  case "$1" in
    ok) echo 2 ;;
    partial) echo 3 ;;
    conflict) echo 1 ;;
    *) echo 8 ;;
  esac
}

# Rellena STATUS_<módulo> una sola vez (algunos checks son lentos).
load_status() {
  local m
  for m in $(supported_modules); do
    eval "STATUS_$m=\"\$(${m}_status)\""
  done
}

module_status() { eval "echo \"\$STATUS_$1\""; }

print_status() {
  local m s
  for m in $(supported_modules); do
    s="$(module_status "$m")"
    printf '  %-10s %s %s\n' "$m" "$(pad "$("${m}_desc")" 55)" \
      "$(gum style --foreground "$(status_color "$s")" "$(status_label "$s")")"
  done
}

header() {
  gum style --border rounded --border-foreground 212 --padding "0 2" --margin "1 0" \
    "$(gum style --bold --foreground 212 'mydotfiles')" \
    "SO: ${TARGET_OS:-$(detect_os)}   ·   repo: $DOTFILES$([[ "$DRY_RUN" == 1 ]] && echo '   ·   DRY-RUN')"
}

# ── Selección ────────────────────────────────────────────────────────────────

# Sin grep -q: con pipefail, si grep sale antes de leerlo todo el productor
# recibe SIGPIPE y la tubería falla aunque haya coincidencia.
is_supported() { supported_modules | grep -xF "$1" >/dev/null; }

module_line() {
  local m="$1"
  printf '%-12s %s  [%s]' "$m" "$("${m}_desc")" "$(status_label "$(module_status "$m")")"
}

# Elige el SO destino. Por defecto, el detectado.
choose_os() {
  local detected choice
  detected="$(detect_os)"
  choice="$(
    printf '%s\n' "mac          macOS" "linux        Linux" "wsl          Windows (WSL)" |
      gum choose --header "Sistema operativo (detectado: $detected)" \
        --selected="$(printf '%s\n' "mac          macOS" "linux        Linux" "wsl          Windows (WSL)" | grep "^$detected ")" |
      awk '{print $1}'
  )"
  [[ -z "$choice" ]] && exit 0
  if [[ "$choice" != "$detected" ]]; then
    log_warn "Has elegido $choice pero esta máquina es $detected: algunos pasos pueden fallar"
    confirm "¿Continuar instalando para $choice?" || exit 0
  fi
  TARGET_OS="$choice"
}

# Elección única entre opciones (más "ninguno"). Imprime los módulos elegidos.
choose_one() {
  local header="$1" opt line lines="" selected=""
  shift
  for opt in "$@"; do
    case "$opt" in
      *+*)
        is_supported "${opt%%+*}" && is_supported "${opt#*+}" || continue
        line="$(printf '%-12s %s' "$opt" "${opt%%+*} y ${opt#*+}")"
        ;;
      *)
        is_supported "$opt" || continue
        line="$(module_line "$opt")"
        [[ -z "$selected" ]] && "${opt}_default" && selected="$line"
        ;;
    esac
    lines="$lines$line"$'\n'
  done
  line="$(printf '%-12s %s' ninguno "No instalar nada")"
  lines="$lines$line"
  [[ -z "$selected" ]] && selected="$line"

  printf '%s\n' "$lines" |
    gum choose --header "$header" --selected="$selected" |
    awk '$1 != "ninguno" {print $1}' | tr '+' '\n'
}

# Elección múltiple de paquetes, preseleccionando los que son por defecto.
# --selected separa por comas: las descripciones no pueden llevarlas.
choose_packages() {
  local m def
  for m in $PACKAGES; do
    is_supported "$m" || continue
    def=0
    "${m}_default" && def=1
    printf '%s\t%s\t%s\n' "$m" "$(module_line "$m")" "$def"
  done | choose_many "Paquetes"
}

# Herramientas CLI una a una, con las de siempre preseleccionadas. Deja la
# elección en TOOLS_SELECTED para el módulo tools.
choose_tools() {
  local id formula def desc state
  tools_prime_cache
  while IFS='|' read -r id formula def desc; do
    state="pendiente"
    tools_is_installed "$id" && state="instalado"
    printf '%s\t%s\t%s\n' "$id" "$(printf '%-10s %s  [%s]' "$id" "$desc" "$state")" "$def"
  done < <(tools_catalog) | choose_many "Herramientas CLI"
}

# Variante de nvim. Siempre propone la del repo, así quien probó la limpia
# puede volver a ella con solo reejecutar.
choose_nvim_variant() {
  local repo limpia
  repo="$(printf '%-12s %s' repo "Config del repo (LazyVim personalizado)")"
  limpia="$(printf '%-12s %s' limpia "LazyVim starter sin personalizar")"
  printf '%s\n' "$repo" "$limpia" |
    gum choose --header "Neovim (actual: $(nvim_current_variant))" --selected="$repo" |
    awk '{print $1}'
}

# Variante de opencode, igual que la de nvim.
choose_opencode_variant() {
  local repo limpia
  repo="$(printf '%-12s %s' repo "Config del repo (agentes · skills · comandos)")"
  limpia="$(printf '%-12s %s' limpia "Sin config: valores por defecto de opencode")"
  printf '%s\n' "$repo" "$limpia" |
    gum choose --header "opencode (actual: $(opencode_current_variant))" --selected="$repo" |
    awk '{print $1}'
}

# Módulos por defecto del SO destino (lo que preselecciona la TUI).
default_modules() {
  local m
  for m in $(supported_modules); do
    "${m}_default" && echo "$m"
  done
}

# Ordena una lista de módulos según MODULES.
in_install_order() {
  local m
  for m in $MODULES; do
    case " $* " in *" $m "*) printf '%s ' "$m" ;; esac
  done
}

run_tui() {
  local picked
  header
  choose_os
  log_info "Comprobando qué está instalado..."
  load_status
  picked="$(
    choose_one "Terminal" $TERMINALS
    choose_one "Intérprete" $SHELLS
    choose_one "Prompt" $PROMPTS
    choose_one "Multiplexor" $MULTIPLEXERS
    choose_packages
  )" || exit 0
  TOOLS_SELECTED="$(choose_tools | tr '\n' ' ')" || exit 0
  TOOLS_SET=1
  [[ -n "${TOOLS_SELECTED// /}" ]] && picked="$picked tools"
  picked="$(in_install_order $picked)"
  if [[ -z "${picked// /}" ]]; then
    log_info "Nada seleccionado"
    exit 0
  fi
  if [[ " $picked " == *" nvim "* && -z "${NVIM_VARIANT:-}" ]]; then
    NVIM_VARIANT="$(choose_nvim_variant)"
    [[ -z "$NVIM_VARIANT" ]] && exit 0
  fi
  if [[ " $picked " == *" opencode "* && -z "${OPENCODE_VARIANT:-}" ]]; then
    OPENCODE_VARIANT="$(choose_opencode_variant)"
    [[ -z "$OPENCODE_VARIANT" ]] && exit 0
  fi

  gum style --border rounded --padding "0 2" --border-foreground 8 \
    "SO: $TARGET_OS" "Módulos: $picked" ${NVIM_VARIANT:+"Neovim: $NVIM_VARIANT"} \
    ${OPENCODE_VARIANT:+"opencode: $OPENCODE_VARIANT"} \
    ${TOOLS_SET:+"Herramientas: ${TOOLS_SELECTED:-ninguna}"}
  confirm "¿Instalar?" || exit 0
  install_modules $picked
}

# ── Instalación ──────────────────────────────────────────────────────────────

install_modules() {
  local m rc failed="" done_list=""
  log_init "$ORIGINAL_ARGS"
  log_file "MODULES $* ${NVIM_VARIANT:+(nvim: $NVIM_VARIANT)} ${OPENCODE_VARIANT:+(opencode: $OPENCODE_VARIANT)}"
  for m in "$@"; do
    gum style --bold --foreground 212 --margin "1 0 0 0" "▸ $m"
    log_file "----- $m"
    # Subshell con -e: un fallo para el módulo pero no el resto
    (
      set -e
      "${m}_install"
    )
    rc=$?
    if [[ $rc == 0 ]]; then
      done_list="$done_list $m"
    else
      log_err "$m falló (código $rc)"
      failed="$failed $m"
    fi
  done

  echo
  log_file "RESULT ok:${done_list:- -} · errores:${failed:- -}"
  [[ -n "$done_list" ]] && gum style --foreground 2 "✓ Completado:$done_list"
  [[ -n "$failed" ]] && gum style --foreground 1 "✗ Con errores:$failed"
  [[ -n "$LOG_FILE" ]] && gum style --foreground 8 "Log: $LOG_FILE"
  [[ -n "$failed" ]] && return 1
  [[ "$DRY_RUN" == 1 ]] || log_info "Abre una nueva terminal para aplicar los cambios de shell"
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
  ORIGINAL_ARGS="$*"
  local mode=tui requested="" m
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -a | --all) mode=all ;;
      -s | --status) mode=status ;;
      -n | --dry-run) DRY_RUN=1 ;;
      -y | --yes) ASSUME_YES=1 ;;
      --tools)
        shift
        TOOLS_SELECTED="$(echo "${1:-}" | tr ',' ' ')"
        TOOLS_SET=1
        ;;
      --nvim)
        shift
        case "${1:-}" in
          repo | limpia) NVIM_VARIANT="$1" ;;
          *)
            log_err "Variante de nvim no válida: ${1:-} (repo | limpia)"
            exit 1
            ;;
        esac
        ;;
      --opencode)
        shift
        case "${1:-}" in
          repo | limpia) OPENCODE_VARIANT="$1" ;;
          *)
            log_err "Variante de opencode no válida: ${1:-} (repo | limpia)"
            exit 1
            ;;
        esac
        ;;
      -o | --os)
        shift
        case "${1:-}" in
          mac | linux | wsl) TARGET_OS="$1" ;;
          *)
            log_err "SO no válido: ${1:-} (mac | linux | wsl)"
            exit 1
            ;;
        esac
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      -*)
        log_err "Opción desconocida: $1"
        usage
        exit 1
        ;;
      *)
        requested="$requested $1"
        mode=list
        ;;
    esac
    shift
  done

  bootstrap

  case "$mode" in
    status)
      header
      load_status
      print_status
      ;;
    all)
      install_modules $(default_modules)
      ;;
    list)
      for m in $requested; do
        if ! is_supported "$m"; then
          log_err "Módulo no disponible en $(os_kind): $m"
          exit 1
        fi
      done
      install_modules $(in_install_order $requested)
      ;;
    tui)
      if [[ ! -t 0 || ! -t 1 ]]; then
        log_err "La TUI necesita una terminal interactiva. Usa --all o indica módulos."
        exit 1
      fi
      run_tui
      ;;
  esac
}

main "$@"
