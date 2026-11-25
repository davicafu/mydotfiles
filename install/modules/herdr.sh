# herdr (multiplexor de agentes de IA en la terminal). Formula de homebrew-core.

herdr_desc() { echo "herdr orquestador de agentes de IA en TUI"; }
# Por defecto en todas las plataformas: gasta mucha menos memoria que Orca
herdr_supported() { return 0; }
herdr_default() { return 0; }

# Puede estar instalado con su script en ~/.local/bin, sin brew
herdr_ok() { has herdr || [[ -x "$HOME/.local/bin/herdr" ]] || brew_satisfied herdr; }

herdr_status() { status_of herdr_ok; }

herdr_install() {
  if herdr_ok; then
    log_skip "herdr ya instalado"
  else
    brew_bundle herdr
  fi
}
