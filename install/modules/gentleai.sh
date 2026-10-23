# gentle-ai (configurador de agentes de IA: engram, SDD, skills). Solo se
# instala el binario, no se ejecuta: con la variante "repo" de opencode
# reescribiría la config versionada en el repo.

gentleai_desc() { echo "gentle-ai configurador de agentes de IA"; }
gentleai_supported() { return 0; }
gentleai_default() { return 0; }

gentleai_status() { status_of brew_satisfied gentleai; }

gentleai_install() {
  brew_bundle gentleai
  log_info "gentle-ai no se ejecuta solo: con la variante repo de opencode reescribiría opencode/"
}
