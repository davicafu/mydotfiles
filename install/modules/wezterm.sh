# WezTerm. En WSL se copia al home de Windows; en macOS/Linux se enlaza.

wezterm_desc() { echo "WezTerm"; }
wezterm_supported() { return 0; }
wezterm_default() { [[ "$(os_kind)" != mac ]]; }

wezterm_target() {
  if [[ "$(os_kind)" == wsl ]]; then
    echo "$(windows_home)/.wezterm.lua"
  else
    echo "$HOME/.wezterm.lua"
  fi
}

wezterm_app_ok() {
  case "$(os_kind)" in
    mac) [[ -d /Applications/WezTerm.app ]] || brew_satisfied wezterm ;;
    linux) has wezterm ;;
    wsl) has winget.exe && winget.exe list --id wez.wezterm -e >/dev/null 2>&1 ;;
  esac
}

# En WSL el fichero es una copia: ok si coincide con el del repo
wezterm_copy_status() {
  local dst
  dst="$(wezterm_target)"
  if [[ ! -f "$dst" ]]; then
    echo pending
  elif cmp -s "$DOTFILES/.wezterm.lua" "$dst"; then
    echo ok
  else
    echo conflict
  fi
}

wezterm_status() {
  local config
  if [[ "$(os_kind)" == wsl ]]; then
    config="$(wezterm_copy_status)"
  else
    config="$(link_status "$DOTFILES/.wezterm.lua" "$HOME/.wezterm.lua")"
  fi
  combine_status "$(status_of wezterm_app_ok)" "$config"
}

wezterm_install_wsl() {
  local home dst
  home="$(windows_home)"
  if [[ -z "$home" ]]; then
    log_err "No se pudo resolver el home de Windows (cmd.exe/wslpath)"
    return 1
  fi
  dst="$home/.wezterm.lua"

  # Desde WSL no sirven symlinks hacia Windows: se copia el fichero
  case "$(wezterm_copy_status)" in
    ok)
      log_skip "$dst ya está al día"
      ;;
    conflict)
      if confirm "$dst difiere del repo. ¿Hacer backup y reemplazar?"; then
        backup "$dst"
        run cp "$DOTFILES/.wezterm.lua" "$dst"
        log_ok "Copiado $dst"
      fi
      ;;
    *)
      run cp "$DOTFILES/.wezterm.lua" "$dst"
      log_ok "Copiado $dst"
      ;;
  esac

  if wezterm_app_ok; then
    log_skip "WezTerm ya instalado en Windows"
  elif has winget.exe; then
    confirm "WezTerm no está instalado en Windows. ¿Instalarlo con winget?" &&
      run winget.exe install --id wez.wezterm -e
  fi
  log_info "La fuente Inconsolata Nerd Font debe instalarse en Windows, no en WSL"
}

wezterm_install() {
  case "$(os_kind)" in
    wsl)
      wezterm_install_wsl
      return
      ;;
    mac)
      if wezterm_app_ok; then
        log_skip "WezTerm ya instalado"
      else
        brew_bundle wezterm
      fi
      ;;
    linux)
      if wezterm_app_ok; then
        log_skip "WezTerm ya instalado"
      else
        log_warn "Instala WezTerm con el gestor de tu distro: https://wezterm.org/install/linux.html"
      fi
      ;;
  esac
  link "$DOTFILES/.wezterm.lua" "$HOME/.wezterm.lua"

  # .wezterm.lua fija default_domain = "WSL:Ubuntu" sin condición
  log_warn ".wezterm.lua arranca en el dominio WSL:Ubuntu, que fuera de Windows no existe"
}
