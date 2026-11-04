#!/usr/bin/env bash
# vigia.sh — uma linha no stdout por arquivo salvo; é o gatilho do Monitor no tutor mode.
# uso: vigia.sh [pasta-ou-arquivo...]   (padrão: pasta atual, sem recursão)
#
# O nvim salva em rajada (arquivo de teste 4913, backup~, swap), então:
# ignora esse lixo e solta no máximo 1 evento por arquivo a cada 2s.

[ $# -eq 0 ] && set -- .
declare -A ultimo

inotifywait -m -q -e close_write -e moved_to --format '%w%f' \
    --exclude '(/\.git/|\.sw[a-z]$|~$|/4913$|\.tmp$|/\.#)' "$@" |
while IFS= read -r f; do
    agora=$(date +%s)
    (( agora - ${ultimo[$f]:-0} < 2 )) && continue
    ultimo[$f]=$agora
    echo "salvo: $(realpath -- "$f")"
done
