#!/usr/bin/env bash

set -euo pipefail

#
# macOS
#
# ps da el %CPU de cada proceso sobre un núcleo (100% = un núcleo entero):
# se divide entre el número de núcleos para que el total quede en 0-100%.
#
if [[ "${OSTYPE:-}" == darwin* ]]; then
  ncpu="$(sysctl -n hw.logicalcpu)"
  ps -A -o %cpu \
    | awk -v n="$ncpu" '{s+=$1} END {printf("%.0f", s / n)}'
  exit 0
fi

#
# Linux / WSL
#
if command -v top >/dev/null 2>&1; then
  top -bn1 \
    | awk '/Cpu/ {
        usage = 100 - $8
        printf("%.0f", usage)
        exit
      }'
  exit 0
fi

echo "--"
