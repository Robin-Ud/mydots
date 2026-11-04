#!/bin/bash
# Testes da detecção do SetNiri.sh (sysfs falso): bash SetNiri_test.sh
set -u
cd "$(dirname "$0")"
# shellcheck source=SetNiri.sh
source ./SetNiri.sh
set +e

falhas=0
confere() {  # nome esperado obtido
    if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FALHA $1: esperava '$2', veio '$3'"; falhas=$((falhas + 1)); fi
}

fake=$(mktemp -d)
trap 'rm -rf "$fake"' EXIT
gpu() {  # pasta classe vendor
    mkdir -p "$fake/bus/pci/devices/$1"
    echo "$2" > "$fake/bus/pci/devices/$1/class"
    echo "$3" > "$fake/bus/pci/devices/$1/vendor"
}
SYS=$fake

mkdir -p "$fake/class/power_supply/AC"
gpu 0000:00:02.0 0x030000 0x8086          # Intel do note
gpu 0000:00:1f.3 0x040380 0x10de          # áudio HDMI da NVIDIA não conta
confere "note sem bateria vira pc"      pc   "$(maquina)"
confere "intel não é nvidia"            não  "$(tem_nvidia && echo sim || echo não)"

mkdir -p "$fake/class/power_supply/BAT0"
confere "com bateria é note"            note "$(maquina)"

gpu 0000:01:00.0 0x030000 0x10de          # placa NVIDIA VGA
confere "nvidia VGA"                    sim  "$(tem_nvidia && echo sim || echo não)"

rm -rf "$fake/bus/pci/devices/0000:01:00.0"
gpu 0000:01:00.0 0x030200 0x10de          # NVIDIA como controladora 3D (híbrido)
confere "nvidia 3D"                     sim  "$(tem_nvidia && echo sim || echo não)"

exit $falhas
