# opencode: agentes, skills, comandos y prompts

opencode_desc() { echo "opencode con skills · comandos SDD y perfiles"; }
opencode_supported() { return 0; }
opencode_default() { return 1; }

opencode_status() {
  combine_status \
    "$(status_of brew_satisfied opencode)" \
    "$(link_status "$DOTFILES/opencode" "$CONFIG_DIR/opencode")"
}

opencode_install() {
  brew_bundle opencode
  link "$DOTFILES/opencode" "$CONFIG_DIR/opencode"
}
