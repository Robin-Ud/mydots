#!/bin/bash
# Pega uma cor da tela com o mouse e copia o hex
# icone: color-picker
hex=$(niri msg --json pick-color | python3 -c '
import json, sys
c = json.load(sys.stdin)
print("#%02X%02X%02X" % tuple(round(v * 255) for v in c["rgb"]))' 2>/dev/null) || exit 0  # Esc = cancelou
printf '%s' "$hex" | wl-copy
echo "$hex copiado"
