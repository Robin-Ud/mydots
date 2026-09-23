#!/bin/bash
CLASS="$1"
shift

ADDRESS=$(hyprctl clients -j | jq -r --arg class "$CLASS" '.[] | select(.class == $class) | .address' | head -1)

if [ -n "$ADDRESS" ]; then
    hyprctl dispatch focuswindow "address:$ADDRESS"
else
    "$@" &
fi
