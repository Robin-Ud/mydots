#!/bin/bash
CLASS="$1"
shift

ADDRESS=$(hyprctl clients -j | jq -r --arg class "$CLASS" '.[] | select(.class == $class) | .address' | head -1)

if [ -n "$ADDRESS" ]; then
    CURRENT_WS=$(hyprctl activeworkspace -j | jq -r '.name')
    hyprctl dispatch movetoworkspacesilent "$CURRENT_WS,address:$ADDRESS"
    hyprctl dispatch focuswindow "address:$ADDRESS"
else
    "$@" &
fi
