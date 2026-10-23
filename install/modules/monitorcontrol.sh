# MonitorControl (brillo y volumen de monitores externos con las teclas del
# Mac). Solo macOS.

monitorcontrol_desc() { echo "MonitorControl brillo de monitores externos"; }
monitorcontrol_supported() { [[ "$(os_kind)" == mac ]]; }
monitorcontrol_default() { return 1; }

# Puede estar instalado desde el .dmg, sin brew
monitorcontrol_app_ok() { [[ -d /Applications/MonitorControl.app ]] || brew_satisfied monitorcontrol; }

monitorcontrol_status() { status_of monitorcontrol_app_ok; }

monitorcontrol_install() {
  if monitorcontrol_app_ok; then
    log_skip "MonitorControl ya instalado"
  else
    brew_bundle monitorcontrol
  fi
}
