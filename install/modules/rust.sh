# Rust con rustup (script oficial en todas las plataformas): toolchain en
# ~/.rustup y binarios en ~/.cargo/bin, que zsh añade al PATH. Se usa rustup y
# no la fórmula rust de brew porque Tauri lo necesita para los targets de
# móvil (rustup target add) y se actualiza solo (rustup update). nvim lo
# instala si falta cargo, para kdlfmt.

rust_desc() { echo "Rust toolchain con rustup (cargo · Tauri)"; }
rust_supported() { return 0; }
rust_default() { return 1; }

rust_ok() { has rustup || [[ -x "$HOME/.cargo/bin/rustup" ]]; }

# cargo aunque ~/.cargo/bin aún no esté en el PATH (justo tras instalar)
rust_cargo() {
  if has cargo; then echo cargo; else echo "$HOME/.cargo/bin/cargo"; fi
}

rust_status() { status_of rust_ok; }

rust_install() {
  if rust_ok; then
    log_skip "rustup ya instalado"
  else
    # --no-modify-path: el PATH lo pone zsh/conf.d, no se toca ~/.zshrc
    run bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path'
    log_ok "Rust instalado en ~/.cargo/bin (actualizar: rustup update)"
  fi
  if has brew && brew list --formula rust >/dev/null 2>&1; then
    log_warn "También está la fórmula rust de brew: con rustup sobra (brew uninstall rust)"
  fi
}
