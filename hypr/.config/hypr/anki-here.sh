#!/bin/bash
ANKI_ADDRESS=$(hyprctl clients -j | jq -r '.[] | select(.class == "net.ankiweb.Anki") | .address' | head -1)

if [ -n "$ANKI_ADDRESS" ]; then
    CURRENT_WS=$(hyprctl activeworkspace -j | jq '.id')
    hyprctl dispatch movetoworkspacesilent "$CURRENT_WS,address:$ANKI_ADDRESS"
    hyprctl dispatch focuswindow "address:$ANKI_ADDRESS"
else
    flatpak run net.ankiweb.Anki &
fi
