#!/bin/bash
OBSIDIAN_ADDRESS=$(hyprctl clients -j | jq -r '.[] | select(.class == "obsidian") | .address' | head -1)

if [ -n "$OBSIDIAN_ADDRESS" ]; then
    CURRENT_WS=$(hyprctl activeworkspace -j | jq '.id')
    hyprctl dispatch movetoworkspacesilent "$CURRENT_WS,address:$OBSIDIAN_ADDRESS"
    hyprctl dispatch focuswindow "address:$OBSIDIAN_ADDRESS"
else
    flatpak run md.obsidian.Obsidian &
fi
