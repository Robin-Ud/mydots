#!/bin/bash
# Volume por janela/app (PipeWire), independente do volume geral.
#
# Uso:  vol-janela.sh up|down|mute   mexe na janela focada (todos os streams dela)
#       vol-janela.sh menu           rofi com todos os apps tocando agora
#
# O WirePlumber lembra o volume de cada app, então o ajuste volta sozinho
# na próxima vez que ele tocar.

PASSO="5%"
LIMITE="1.5"   # deixa passar de 100%, igual ao volume geral

# Funciona no Hyprland e no niri (NIRI_SOCKET só existe dentro do niri)
avisa() {
    if [ -n "$NIRI_SOCKET" ]; then
        # a dica "synchronous" faz a notificação nova substituir a anterior
        notify-send -t 1500 -h string:x-canonical-private-synchronous:vol-janela "$1"
        return
    fi
    hyprctl dismissnotify >/dev/null
    hyprctl notify -1 1500 "rgb(89b4fa)" "fontsize:14 $1" >/dev/null
}

# pid e classe/app_id da janela focada, separados por espaço
focada() {
    if [ -n "$NIRI_SOCKET" ]; then
        niri msg -j focused-window | jq -r '"\(.pid) \(.app_id)"'
    else
        hyprctl activewindow -j | jq -r '"\(.pid) \(.class)"'
    fi
}

# id ␟ pids (process.id e sec.pid) ␟ app_id do flatpak ␟ nome ␟ mídia
# (separador \x1f: com TAB o read do bash engole campo vazio)
streams() {
    pw-dump | jq -r '.[] | select(.info.props["media.class"] == "Stream/Output/Audio")
        | .info.props as $p
        | [(.id | tostring),
           ([$p["application.process.id"], $p["pipewire.sec.pid"]] | map(select(. != null) | tostring) | join(" ")),
           ($p["pipewire.access.portal.app_id"] // ""),
           ($p["application.name"] // $p["node.name"] // "?"),
           ($p["media.name"] // "")] | join("\u001f")'
}

# true se $2 é o próprio $1 ou um descendente dele
descende_de() {
    local alvo=$1 p=$2
    while [ -n "$p" ] && [ "$p" -gt 1 ]; do
        [ "$p" = "$alvo" ] && return 0
        p=$(awk '{print $4}' "/proc/$p/stat" 2>/dev/null)
    done
    return 1
}

# "70%" ou "70% mudo"
volume_de() {
    wpctl get-volume "$1" 2>/dev/null | awk '{printf "%d%%%s", $2*100+0.5, ($3 ? " mudo" : "")}'
}

janela_focada() {
    local pid classe ids=() nome=""
    read -r pid classe < <(focada)

    while IFS=$'\x1f' read -r id pids appid app _; do
        local casou=""
        [ -n "$appid" ] && [ "$appid" = "$classe" ] && casou=1
        for p in $pids; do descende_de "$pid" "$p" && casou=1; done
        [ -n "$casou" ] && ids+=("$id") && nome=$app
    done < <(streams)

    if [ ${#ids[@]} -eq 0 ]; then
        avisa "Sem áudio tocando em: $classe"
        exit 0
    fi

    for id in "${ids[@]}"; do
        case $1 in
            up)   wpctl set-volume -l "$LIMITE" "$id" "$PASSO+" ;;
            down) wpctl set-volume "$id" "$PASSO-" ;;
            mute) wpctl set-mute "$id" toggle ;;
        esac
    done
    avisa "🔊 $nome: $(volume_de "${ids[0]}")"
}

menu() {
    local escolha id nome acao
    while :; do
        escolha=$(streams | while IFS=$'\x1f' read -r id _ _ app midia; do
            printf '%s\t%-8s %s — %s\n' "$id" "$(volume_de "$id")" "$app" "$midia"
        done | rofi -dmenu -i -p "Volume" -display-columns 2 -display-column-separator $'\t' \
                    -mesg "Sem nada aqui? Nenhum app está tocando agora.")
        [ -z "$escolha" ] && return
        id=${escolha%%$'\t'*}
        nome=${escolha#*$'\t'}

        acao=$(printf '+10\n-10\nmudo\n100\n50\n25\n' | rofi -dmenu -p "$nome" \
                   -mesg "Escolha ou digite um número (ex.: 40)")
        case $acao in
            "")   continue ;;
            mudo) wpctl set-mute "$id" toggle ;;
            +*)   wpctl set-volume -l "$LIMITE" "$id" "${acao#+}%+" ;;
            -*)   wpctl set-volume "$id" "${acao#-}%-" ;;
            *[!0-9]*) avisa "Número inválido: $acao" ;;
            *)    wpctl set-volume -l "$LIMITE" "$id" "$acao%" ;;
        esac
    done
}

case $1 in
    up|down|mute) janela_focada "$1" ;;
    menu)         menu ;;
    *) echo "uso: $0 up|down|mute|menu" >&2; exit 1 ;;
esac
