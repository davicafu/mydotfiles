# Inicio instantáneo de powerlevel10k. Tiene que ser lo primero: todo lo que
# pida input o imprima algo va después.
#
# direnv se carga aquí y no en 40-tools: si la shell arranca en una carpeta con
# .envrc, sus mensajes de "loading" saldrían tras el instant prompt y p10k
# avisaría. Brew aún no está en el PATH, así que se busca el binario a mano.
_direnv_bin=${commands[direnv]:-}
for _p in /opt/homebrew/bin/direnv /home/linuxbrew/.linuxbrew/bin/direnv /usr/local/bin/direnv; do
  [[ -z $_direnv_bin && -x $_p ]] && _direnv_bin=$_p
done
unset _p
[[ -n $_direnv_bin ]] && emulate zsh -c "$("$_direnv_bin" export zsh)"

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${USER}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${USER}.zsh"
fi

[[ -n $_direnv_bin ]] && emulate zsh -c "$("$_direnv_bin" hook zsh)"
unset _direnv_bin
