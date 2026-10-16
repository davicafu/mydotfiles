#!/usr/bin/env bash

set -euo pipefail

#
# macOS
#
# No hay `free`: se calcula con vm_stat como "Memoria usada" del Monitor de
# Actividad (memoria de apps + fija + comprimida), sin la caché de ficheros.
#
if [[ "${OSTYPE:-}" == darwin* ]]; then
  total="$(sysctl -n hw.memsize)"
  vm_stat | awk -v total="$total" '
    /page size of/            { page = $8 }
    /^Anonymous pages/        { anon = $3 }
    /^Pages purgeable/        { purge = $3 }
    /^Pages wired down/       { wired = $4 }
    /^Pages occupied by compressor/ { comp = $5 }
    END {
      gib = 1024 * 1024 * 1024
      used = (anon - purge + wired + comp) * page
      printf("%.1fGi/%.0fGi", used / gib, total / gib)
    }'
  exit 0
fi

#
# Linux / WSL
#
if command -v free >/dev/null 2>&1; then
  free -h | awk '/Mem:/ {print $3 "/" $2; exit}'
  exit 0
fi

echo "--"
