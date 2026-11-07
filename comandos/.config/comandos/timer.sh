#!/bin/bash
# Timer: "timer 10m chá" avisa daqui a 10 min (número sozinho = minutos)
# icone: alarm
# modo: fundo
t=${1:-5m}; shift
[[ $t =~ ^[0-9]+([.][0-9]+)?$ ]] && t="${t}m"
msg=${*:-Acabou o timer de $t}
sleep "$t" 2>/dev/null || { notify-send -u critical "Timer" "Tempo inválido: $t (ex.: 30s, 10m, 1h)"; exit 1; }
notify-send -u critical -i alarm "⏰ Timer ($t)" "$msg"
som=/usr/share/sounds/freedesktop/stereo/complete.oga
[ -f "$som" ] && pw-play "$som" 2>/dev/null
