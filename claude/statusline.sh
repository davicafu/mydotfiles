#!/bin/sh
# Barra de estado de Claude Code: modelo y effort, contexto, uso de 5 h, semanal y semanal de Fable.
# Dentro de Orca reenvía además el JSON a su hook, para que Orca siga mostrando su panel de uso.
payload=$(cat)

orca_hook="$HOME/.orca/agent-hooks/claude-statusline.sh"
if [ -n "${ORCA_PANE_KEY-}${ORCA_AGENT_PANE-}" ] && [ -x "$orca_hook" ]; then
  printf '%s' "$payload" | /bin/sh "$orca_hook" >/dev/null 2>&1 &
fi

# El semanal de Fable no viene en el JSON: se lee de la API de uso de la cuenta, en caché 5 min.
# El token sale del llavero, solo va a api.anthropic.com y nunca se escribe en disco.
cache="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline-fable.json"
age=999999
[ -f "$cache" ] && age=$(( $(date +%s) - $(stat -f %m "$cache") ))
if [ "$age" -ge 300 ]; then
  mkdir -p "$(dirname "$cache")"
  touch "$cache" # reserva el refresco para que las sesiones en paralelo no consulten todas
  (
    tok=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty')
    [ -n "$tok" ] || exit 0
    curl -sS --max-time 8 https://api.anthropic.com/api/oauth/usage \
      -H "Authorization: Bearer $tok" -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null \
      | jq -c '[.limits[]? | select(.kind == "weekly_scoped" and (.scope.model.display_name // "" | ascii_downcase) == "fable")][0] // empty | {percent, resets_at}' \
      > "$cache.tmp" 2>/dev/null && [ -s "$cache.tmp" ] && mv "$cache.tmp" "$cache"
    rm -f "$cache.tmp"
  ) >/dev/null 2>&1 &
fi
fable=$(cat "$cache" 2>/dev/null)
[ -n "$fable" ] || fable=null

printf '%s' "$payload" | jq -r --argjson fable "$fable" '
  def pct: (. | floor | tostring) + "%";
  def epoch: if type == "number" then . elif type == "string" then (.[0:19] | strptime("%Y-%m-%dT%H:%M:%S") | mktime) else null end;
  def until($fmt): (.resets_at | epoch) as $t | if $t == null then "" else " ↻ " + ($t | strflocaltime($fmt)) end;
  def win($label; $fmt): if . == null then empty
    else (.used_percentage // .utilization // .percent) as $p | if $p == null then empty else "\($label) \($p | pct)\(until($fmt))" end end;
  [
    ([.model.display_name, .effort.level] | map(select(. != null)) | join(" ") | select(. != "")),
    (.context_window.used_percentage // null | if . == null then empty else "ctx \(pct)" end),
    (.rate_limits.five_hour | win("5h"; "%H:%M")),
    (.rate_limits.seven_day | win("sem"; "%a %H:%M")),
    ($fable | win("Fable"; "%a"))
  ] | join(" · ")
' 2>/dev/null
