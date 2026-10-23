# herdr (multiplexor de agentes de IA en la terminal). Formula de homebrew-core.

herdr_desc() { echo "herdr orquestador de agentes de IA en TUI sin app móvil"; }
# En linux/wsl sustituye a Orca, que solo existe para mac
herdr_supported() { return 0; }
herdr_default() { [[ "$(os_kind)" != mac ]]; }

herdr_status() { status_of brew_satisfied herdr; }

herdr_install() {
  brew_bundle herdr
}
