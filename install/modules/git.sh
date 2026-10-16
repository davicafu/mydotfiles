# git: config global (git/config) incluida desde ~/.gitconfig + identidad

git_desc() { echo "git + git-lfs y config global (aliases · colores)"; }
git_supported() { return 0; }
git_default() { return 0; }

git_config_file() { echo "$DOTFILES/git/config"; }

git_included() {
  git config --global --get-all include.path 2>/dev/null | grep -xF "$(git_config_file)" >/dev/null
}

git_identity_ok() {
  git config --global --get user.name >/dev/null && git config --global --get user.email >/dev/null
}

git_status() {
  combine_status \
    "$(status_of brew_satisfied git)" \
    "$(status_of git_included)" \
    "$(status_of git_identity_ok)"
}

# Pide un valor con gum, precargado con el actual. Vacío = mantener el actual.
git_ask() {
  local key="$1" header="$2" placeholder="$3" current value
  current="$(git config --global --get "$key" 2>/dev/null)"
  value="$(gum input --header "$header" --placeholder "$placeholder" --value "$current")"
  [[ -z "$value" ]] && value="$current"
  echo "$value"
}

# Configura user.name y user.email globales para este ordenador.
git_set_identity() {
  local name email
  if [[ "$DRY_RUN" == 1 ]]; then
    log_info "Se pediría nombre y email para user.name/user.email"
    return 0
  fi
  # Sin terminal o con --yes no se pregunta: se respeta lo que haya
  if [[ "$ASSUME_YES" == 1 || ! -t 0 ]]; then
    git_identity_ok && log_skip "Identidad de git ya configurada" ||
      log_warn "Falta user.name/user.email: ejecuta ./install.sh git sin --yes"
    return 0
  fi

  name="$(git_ask user.name "Nombre para los commits (git user.name)" "Tu Nombre")"
  while :; do
    email="$(git_ask user.email "Email para los commits (git user.email)" "tu@email.com")"
    [[ -z "$email" || "$email" == *@*.* ]] && break
    log_warn "Email no válido: $email"
  done

  git_set_global user.name "$name"
  git_set_global user.email "$email"
}

git_set_global() {
  local key="$1" value="$2"
  if [[ -z "$value" ]]; then
    log_warn "$key sin configurar"
  elif [[ "$(git config --global --get "$key")" == "$value" ]]; then
    log_skip "$key ya es $value"
  else
    git config --global "$key" "$value"
    log_ok "$key = $value"
  fi
}

# Avisa de claves que ~/.gitconfig ya define con otro valor: el include va
# al final del fichero, así que gana el valor del repo.
git_report_overrides() {
  local key value current
  git config -f "$(git_config_file)" --list | while IFS='=' read -r key value; do
    current="$(git config --global --no-includes --get "$key" 2>/dev/null)" || continue
    [[ "$current" == "$value" ]] && continue
    log_warn "~/.gitconfig tenía $key=$current, pasa a $value"
  done
}

git_install() {
  brew_bundle git

  if git_included; then
    log_skip "~/.gitconfig ya incluye $(git_config_file)"
  else
    git_report_overrides
    run git config --global --add include.path "$(git_config_file)"
    log_ok "~/.gitconfig incluye $(git_config_file)"
  fi

  git_set_identity
}
