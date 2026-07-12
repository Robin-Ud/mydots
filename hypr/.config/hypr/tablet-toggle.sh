#!/bin/bash
# Cicla o mapeamento da mesa digitalizadora: notebook → LG UltraGear → ambos → ...
# Alt+W no hyprland.conf chama este script.

DEVICE="wacom-intuos-bt-s-pen"
STATE_FILE="/tmp/hypr_tablet_output"

CURRENT=$(cat "$STATE_FILE" 2>/dev/null || echo "eDP-1")

case "$CURRENT" in
    "eDP-1")
        TARGET="HDMI-A-1"
        LABEL="LG UltraGear (HDMI-A-1)"
        ;;
    "HDMI-A-1")
        TARGET=""
        LABEL="Ambos os monitores"
        ;;
    *)
        TARGET="eDP-1"
        LABEL="Notebook (eDP-1)"
        ;;
esac

hyprctl keyword "device[$DEVICE]:output" "$TARGET"
echo "$TARGET" > "$STATE_FILE"
notify-send -t 2000 "Mesa Digitalizadora" "Mapeada para $LABEL"
