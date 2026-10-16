# Funciones con fzf
cdf() {
  local dir
  dir=$(fd --type d --hidden --exclude .git | fzf --height 90% --layout reverse --border --preview 'eza --tree --level=2 --icons {}') || return
  cd "$dir"
}

fkill() {
  local pid
  pid=$(ps aux | fzf --height 80% --layout reverse --border | awk '{print $2}') || return
  [[ -n "$pid" ]] && kill -9 "$pid"
}

ff() {
  local file
  file=$(fd --type f --hidden --exclude .git | fzf --height 90% --layout reverse --border --preview 'bat --style=numbers --color=always --line-range :200 {}') || return
  nvim "$file"
}
zle -N ff-widget ff
bindkey '^F' ff-widget

fg() {
  local selected file line
  selected=$(rg --line-number --column --smart-case "$1" | fzf --delimiter : --preview 'bat --style=numbers --color=always --highlight-line {2} {1}') || return
  file=$(echo "$selected" | cut -d: -f1)
  line=$(echo "$selected" | cut -d: -f2)
  nvim "+$line" "$file"
}

glc() {
  git rev-parse --is-inside-work-tree > /dev/null 2>&1 || { echo "Not inside a git repository"; return 1; }
  local commit file
  commit="$(git rev-parse HEAD)"
  file=$(git show --name-only --pretty=format: "$commit" | sed '/^$/d' | fzf --height 90% --layout reverse --border --header "Last commit: $(git log -1 --pretty=format:'%h %s')" --preview "git show --color=always --stat --patch -- {}") || return
  nvim "$file"
}

gls() {
  local file
  file=$( (git diff --name-only; git diff --cached --name-only; git ls-files --others --exclude-standard) | sort -u | fzf --height=90% --layout=reverse --border --header="Working tree changes" --preview 'if git ls-files --error-unmatch {} >/dev/null 2>&1; then git diff --color=always -- {}; git diff --cached --color=always -- {}; else bat --color=always --style=numbers {}; fi') || return
  nvim "$file"
}

zj() {
  local layouts=(everforest kanagawa kanagawa-bg sakura sakura-bg)
  local selected=${layouts[$((RANDOM % ${#layouts[@]} + 1))]}
  zellij --layout "$selected"
}
