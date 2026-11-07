#!/bin/bash
# Mostra o IP local e o do Tailscale; copia o local
# icone: network
local=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit }}')
ts=$(tailscale ip -4 2>/dev/null | head -1)
echo "Local: ${local:-sem rede}"
echo "Tailscale: ${ts:-desligado}"
[ -n "$local" ] && printf '%s' "$local" | wl-copy && echo "(local copiado)"
