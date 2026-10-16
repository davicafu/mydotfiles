#!/usr/bin/env bash
# Helpers compartidos por install.sh y los módulos.
# Compatible con bash 3.2 (el /bin/bash de macOS): nada de arrays asociativos,
# ${var,,}, mapfile ni [[ -v ]].

DOTFILES="${DOTFILES:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

# ── Logging ──────────────────────────────────────────────────────────────────

# Cada ejecución deja un log en texto plano en ~/.cache/mydotfiles/. Se
# escribe desde los log_* y run(), no redirigiendo toda la salida: gum
# necesita la terminal para dibujar la TUI.
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/mydotfiles"
LOG_FILE="${LOG_FILE:-}"
LOG_KEEP=20

log_init() {
  mkdir -p "$LOG_DIR" 2>/dev/null || return 0
  LOG_FILE="$LOG_DIR/install-$TIMESTAMP.log"
  {
    echo "# mydotfiles install $(date '+%Y-%m-%d %H:%M:%S')"
    echo "# args: $*"
    echo "# so: $(os_kind) (detectado: $(detect_os)) · dry-run: $DRY_RUN · yes: $ASSUME_YES"
    echo "# repo: $DOTFILES @ $(git -C "$DOTFILES" rev-parse --short HEAD 2>/dev/null)$(
      [[ -n "$(git -C "$DOTFILES" status --porcelain 2>/dev/null)" ]] && echo ' (con cambios)'
    )"
  } >"$LOG_FILE"
  # Conserva solo los últimos LOG_KEEP
  ls -1t "$LOG_DIR"/install-*.log 2>/dev/null | tail -n +$((LOG_KEEP + 1)) | while read -r old; do
    rm -f "$old"
  done
}

log_file() {
  [[ -n "$LOG_FILE" ]] && printf '%s %s\n' "$(date +%H:%M:%S)" "$*" >>"$LOG_FILE"
  return 0
}

log_info() { printf '  \033[34m•\033[0m %s\n' "$*"; log_file "INFO  $*"; }
log_ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; log_file "OK    $*"; }
log_skip() { printf '  \033[90m↷ %s\033[0m\n' "$*"; log_file "SKIP  $*"; }
log_warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; log_file "WARN  $*"; }
log_err() { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; log_file "ERROR $*"; }

# ── Plataforma ───────────────────────────────────────────────────────────────

# SO detectado de la máquina actual.
detect_os() {
  if [[ "${OSTYPE:-}" == darwin* ]]; then
    echo mac
  elif grep -qi microsoft /proc/version 2>/dev/null; then
    echo wsl
  else
    echo linux
  fi
}

# SO para el que se instala: el elegido en la TUI/--os o el detectado.
os_kind() { echo "${TARGET_OS:-$(detect_os)}"; }

has() { command -v "$1" >/dev/null 2>&1; }

# Rellena con espacios hasta N caracteres (printf %-Ns cuenta bytes, no
# caracteres, y descuadra con tildes).
pad() {
  local text="$1" width="$2"
  printf '%s%*s' "$text" $((width - ${#text})) ''
}

# ── Ejecución ────────────────────────────────────────────────────────────────

# Ejecuta un comando, o solo lo muestra en modo --dry-run. El comando y su
# stderr quedan también en el log.
run() {
  local rc
  if [[ "$DRY_RUN" == 1 ]]; then
    printf '  \033[90m[dry-run] %s\033[0m\n' "$*"
    log_file "DRY   $*"
    return 0
  fi
  log_file "RUN   $*"
  if [[ -n "$LOG_FILE" ]]; then
    "$@" 2> >(tee -a "$LOG_FILE" >&2)
  else
    "$@"
  fi
  rc=$?
  [[ $rc != 0 ]] && log_file "FAIL  ($rc) $*"
  return $rc
}

# Pregunta sí/no. Con --yes o --dry-run responde siempre que sí.
confirm() {
  [[ "$ASSUME_YES" == 1 || "$DRY_RUN" == 1 ]] && return 0
  gum confirm "$1"
}

# ── Symlinks ─────────────────────────────────────────────────────────────────

# Quita la barra final para comparar rutas ("dir/" == "dir").
_strip_slash() {
  local p="$1"
  while [[ "$p" == */ && "$p" != / ]]; do p="${p%/}"; done
  echo "$p"
}

# Estado de un enlace: ok | pending | conflict
link_status() {
  local src dst target
  src="$(_strip_slash "$1")"
  dst="$2"
  if [[ -L "$dst" ]]; then
    target="$(_strip_slash "$(readlink "$dst")")"
    [[ "$target" == "$src" ]] && echo ok || echo conflict
  elif [[ -e "$dst" ]]; then
    echo conflict
  else
    echo pending
  fi
}

# Mueve una ruta existente a <ruta>.backup-<timestamp>.
backup() {
  local path="$1" dest="$1.backup-$TIMESTAMP"
  run mv "$path" "$dest"
  log_warn "Backup: $path → $dest"
}

# Crea src ← dst de forma idempotente. Si dst ya existe y no apunta a src,
# lo respalda antes (nunca borra nada).
link() {
  local src="$1" dst="$2"
  case "$(link_status "$src" "$dst")" in
    ok)
      log_skip "$dst ya enlazado"
      return 0
      ;;
    conflict)
      if ! confirm "$dst ya existe y no apunta a $src. ¿Hacer backup y reemplazar?"; then
        log_warn "Omitido $dst"
        return 0
      fi
      backup "$dst"
      ;;
  esac
  run mkdir -p "$(dirname "$dst")"
  run ln -s "$src" "$dst"
  log_ok "$dst → $src"
}

# ── Ficheros ─────────────────────────────────────────────────────────────────

# Añade una línea a un fichero solo si no está ya (nunca sobrescribe).
ensure_line() {
  local file="$1" line="$2"
  if [[ -f "$file" ]] && grep -qxF "$line" "$file"; then
    log_skip "$file ya contiene: $line"
    return 0
  fi
  if [[ "$DRY_RUN" == 1 ]]; then
    run "echo '$line' >> $file"
  else
    printf '%s\n' "$line" >>"$file"
  fi
  log_ok "Añadido a $file: $line"
}

# Quita una línea exacta de un fichero, con backup previo del fichero.
remove_line() {
  local file="$1" line="$2" tmp
  if [[ -L "$file" ]]; then
    log_err "$file es un enlace: no se edita para no modificar su destino"
    return 1
  fi
  run cp -p "$file" "$file.backup-$TIMESTAMP"
  if [[ "$DRY_RUN" == 1 ]]; then
    run "quitar de $file: $line"
  else
    tmp="$(mktemp)"
    grep -vxF "$line" "$file" >"$tmp" || true
    cat "$tmp" >"$file"
    rm -f "$tmp"
  fi
  log_ok "Quitado de $file (backup en $file.backup-$TIMESTAMP): $line"
}

# Clona un repo si no existe ya. Argumentos extra se pasan a git clone.
git_clone() {
  local repo="$1" dst="$2"
  shift 2
  if [[ -d "$dst/.git" ]]; then
    log_skip "$(basename "$dst") ya clonado"
    return 0
  fi
  run git clone --depth 1 "$@" "$repo" "$dst"
  log_ok "Clonado $(basename "$dst")"
}

# Descarga y descomprime un zip en un directorio.
fetch_zip() {
  local url="$1" dst="$2" tmp
  tmp="$(mktemp -d)"
  run curl -fsSL -o "$tmp/pkg.zip" "$url"
  run mkdir -p "$dst"
  run unzip -oq "$tmp/pkg.zip" -d "$dst"
  rm -rf "$tmp"
}

# ── Homebrew ─────────────────────────────────────────────────────────────────

brewfile() { echo "$DOTFILES/install/brew/$1.Brewfile"; }

# true si todas las dependencias del Brewfile del módulo están instaladas
# (las desactualizadas cuentan como instaladas).
brew_satisfied() {
  has brew && brew bundle check --no-upgrade --file="$(brewfile "$1")" >/dev/null 2>&1
}

# Instala lo que falte del Brewfile del módulo sin actualizar lo ya instalado.
brew_bundle() {
  local file
  file="$(brewfile "$1")"
  if brew_satisfied "$1"; then
    log_skip "Paquetes de $1 ya instalados"
    return 0
  fi
  if [[ "$DRY_RUN" == 1 ]]; then
    # check sale con 1 cuando falta algo: es justo lo que queremos listar
    { brew bundle check --verbose --no-upgrade --file="$file" 2>&1 || true; } |
      sed -n 's/^→ /  [dry-run] brew bundle: /p'
    return 0
  fi
  brew bundle install --no-upgrade --file="$file"
  log_ok "Paquetes de $1 instalados"
}

# ── WSL ──────────────────────────────────────────────────────────────────────

# win32yank para el portapapeles de tmux y nvim en WSL.
install_win32yank() {
  local bin="$HOME/.local/bin/win32yank.exe" tmp
  if [[ -x "$bin" ]]; then
    log_skip "win32yank ya instalado"
    return 0
  fi
  tmp="$(mktemp -d)"
  fetch_zip "https://github.com/equalsraf/win32yank/releases/latest/download/win32yank-x64.zip" "$tmp"
  run mkdir -p "$HOME/.local/bin"
  run mv "$tmp/win32yank.exe" "$bin"
  run chmod +x "$bin"
  rm -rf "$tmp"
  log_ok "win32yank instalado en $bin"
}

# Directorio home de Windows visto desde WSL (/mnt/c/Users/<user>).
windows_home() {
  local profile
  profile="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
  [[ -n "$profile" ]] && wslpath "$profile"
}

# ── Estado ───────────────────────────────────────────────────────────────────

# Combina varios estados en uno: ok | pending | partial | conflict
combine_status() {
  local s any_ok=0 any_pending=0
  for s in "$@"; do
    case "$s" in
      conflict) echo conflict && return ;;
      ok) any_ok=1 ;;
      *) any_pending=1 ;;
    esac
  done
  if [[ $any_pending == 0 ]]; then
    echo ok
  elif [[ $any_ok == 1 ]]; then
    echo partial
  else
    echo pending
  fi
}

# Convierte una condición (exit code) en ok | pending.
status_of() { "$@" >/dev/null 2>&1 && echo ok || echo pending; }

# ── Selección múltiple ───────────────────────────────────────────────────────

# Lista de selección múltiple que marca con espacio o x (gum choose solo usa x
# o tab y no deja cambiar las teclas). Lee de stdin líneas
# "valor<TAB>texto<TAB>1|0" (1 = preseleccionado) e imprime los valores
# elegidos, uno por línea. Dibuja en /dev/tty para poder usarse dentro de $(...).
# Teclas: espacio/x marcar · ↑↓/k j mover · a todos · enter confirmar · esc salir
choose_many() {
  local header="$1" values=() labels=() marks=() n=0 cur=0 i key rest saved line
  while IFS=$'\t' read -r line rest; do
    [[ -z "$line" ]] && continue
    values[n]="$line"
    labels[n]="${rest%$'\t'*}"
    marks[n]="${rest##*$'\t'}"
    n=$((n + 1))
  done
  [[ $n == 0 ]] && return 0

  saved="$(stty -g </dev/tty)"
  _choose_many_restore() {
    stty "$saved" </dev/tty
    printf '\033[?25h' >/dev/tty
  }
  trap '_choose_many_restore; exit 130' INT TERM
  stty -echo -icanon </dev/tty
  printf '\033[?25l' >/dev/tty

  _choose_many_draw() {
    local j cursor box
    printf '\033[2K\033[90m%s\033[0m\n' "$header"
    for ((j = 0; j < n; j++)); do
      cursor="  "
      [[ $j == "$cur" ]] && cursor=$'\033[38;5;212m>\033[0m '
      if [[ "${marks[j]}" == 1 ]]; then box=$'\033[32m✓\033[0m'; else box=$'\033[90m•\033[0m'; fi
      printf '\033[2K%s%s %s\n' "$cursor" "$box" "${labels[j]}"
    done
    printf '\033[2K\033[90m%s\033[0m\n' "espacio/x marcar · ↑↓ mover · a todos · enter confirmar · esc salir"
  }

  _choose_many_draw >/dev/tty
  while :; do
    IFS= read -rsn1 key </dev/tty
    case "$key" in
      $'\033')
        rest=""
        IFS= read -rsn2 -t 1 rest </dev/tty
        case "$rest" in
          "[A" | "OA") ((cur > 0)) && cur=$((cur - 1)) ;;
          "[B" | "OB") ((cur < n - 1)) && cur=$((cur + 1)) ;;
          "")
            _choose_many_restore
            trap - INT TERM
            return 130
            ;;
        esac
        ;;
      k) ((cur > 0)) && cur=$((cur - 1)) ;;
      j) ((cur < n - 1)) && cur=$((cur + 1)) ;;
      " " | x | X)
        if [[ "${marks[cur]}" == 1 ]]; then marks[cur]=0; else marks[cur]=1; fi
        ;;
      a | $'\001')
        # Si todo está marcado desmarca todo; si no, marca todo
        rest=0
        for ((i = 0; i < n; i++)); do [[ "${marks[i]}" == 1 ]] || rest=1; done
        for ((i = 0; i < n; i++)); do marks[i]=$rest; done
        ;;
      "") break ;;
    esac
    printf '\033[%dA' $((n + 2)) >/dev/tty
    _choose_many_draw >/dev/tty
  done

  _choose_many_restore
  trap - INT TERM
  for ((i = 0; i < n; i++)); do
    [[ "${marks[i]}" == 1 ]] && echo "${values[i]}"
  done
  return 0
}
