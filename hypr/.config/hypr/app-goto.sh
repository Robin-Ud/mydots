#!/bin/bash
CLASS="$1"
shift

ADDRESS=$(hyprctl clients -j | jq -r --arg class "$CLASS" '.[] | select(.class == $class) | .address' | head -1)

if [ -n "$ADDRESS" ]; then
    hyprctl dispatch focuswindow "address:$ADDRESS"
else
    # Debounce: o flatpak leva uns segundos pra mostrar janela; sem isso,
    # apertar o bind de novo nesse meio-tempo sobe instâncias paralelas.
    STAMP="${XDG_RUNTIME_DIR:-/tmp}/app-here-$CLASS.stamp"
    if [ -f "$STAMP" ] && [ $(( $(date +%s) - $(stat -c %Y "$STAMP") )) -lt 10 ]; then
        exit 0
    fi
    touch "$STAMP"
    "$@" &
fi
