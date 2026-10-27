#!/usr/bin/env bash

set -euo pipefail

#
# macOS
#
# Presión de memoria = 100 - "System-wide memory free percentage" de
# memory_pressure (el mismo dato que usa el Monitor de Actividad).
# El nivel del kernel (1 normal, 2 aviso, 4 crítico) decide el color.
#
if [[ "${OSTYPE:-}" == darwin* ]]; then
  free="$(memory_pressure | awk '/free percentage/ { gsub("%", "", $5); print $5 }')"
  level="$(sysctl -n kern.memorystatus_vm_pressure_level)"
  case "$level" in
    2) color="#[fg=yellow]" ;;
    4) color="#[fg=red,bold]" ;;
    *) color="" ;;
  esac
  printf "%s%d" "$color" "$((100 - free))"
  exit 0
fi

echo "--"
