# Zed (editor de texto). En macOS con brew; en Linux con el script oficial.

zed_desc() { echo "Zed editor de texto"; }
zed_supported() { [[ "$(os_kind)" != wsl ]]; }
zed_default() { return 1; }

# Puede estar instalado desde el .dmg o el script, sin brew
zed_app_ok() {
  case "$(os_kind)" in
    mac) [[ -d /Applications/Zed.app ]] || brew_satisfied zed ;;
    *) has zed || [[ -x "$HOME/.local/bin/zed" ]] ;;
  esac
}

zed_status() { status_of zed_app_ok; }

zed_install() {
  if zed_app_ok; then
    log_skip "Zed ya instalado"
    return 0
  fi
  case "$(os_kind)" in
    mac) brew_bundle zed ;;
    linux)
      run sh -c 'curl -fsSL https://zed.dev/install.sh | sh'
      log_ok "Zed instalado en ~/.local"
      ;;
  esac
}
