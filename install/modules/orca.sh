# Orca (orquestador de agentes de IA). Solo macOS, desde el tap de stablyai:
# el cask "orca" de homebrew-core es otro programa (plotly orca).

orca_desc() { echo "Orca orquestador de agentes de IA"; }
orca_supported() { [[ "$(os_kind)" == mac ]]; }
orca_default() { return 0; }

# Puede estar instalado desde el .dmg, sin brew
orca_app_ok() { [[ -d /Applications/Orca.app ]] || brew_satisfied orca; }

orca_status() { status_of orca_app_ok; }

orca_install() {
  if orca_app_ok; then
    log_skip "Orca ya instalado"
  else
    brew_bundle orca
  fi
}
