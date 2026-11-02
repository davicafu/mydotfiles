# pi (agente de programación en la terminal, pi.dev). Fórmula de homebrew-core,
# depende de node.

pi_desc() { echo "pi agente de programación de IA en la terminal"; }
pi_supported() { return 0; }
pi_default() { return 1; }

# Puede estar instalado sin brew (npm, mise...)
pi_ok() { has pi || brew_satisfied pi; }

pi_status() { status_of pi_ok; }

pi_install() {
  if pi_ok; then
    log_skip "pi ya instalado"
  else
    brew_bundle pi
  fi
}
