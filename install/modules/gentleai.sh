# gentle-ai (configurador de agentes de IA: engram, SDD, skills). Solo se
# instala el binario, no se ejecuta: `gentle-ai install` reescribe la config
# de cada agente (en opencode, la copia de ~/.config/opencode, no el repo).
# También instala Gentle Shell (módulo gentleshell).

gentleai_desc() { echo "gentle-ai configurador de agentes de IA"; }
gentleai_supported() { return 0; }
gentleai_default() { return 0; }

gentleai_status() { status_of brew_satisfied gentleai; }

gentleai_install() {
  brew_bundle gentleai
  log_info "gentle-ai no se ejecuta solo: gentle-ai install configura tus agentes (lo que escriba en ~/.config/opencode no vuelve al repo)"
}
