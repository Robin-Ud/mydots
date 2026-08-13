#!/usr/bin/env bash
# bashrc_test.sh — testa o hook do UsageTracker do .bashrc.
#
# Roda num HOME falso em /tmp: não encosta no ~/.local/share/usage-tracker
# de verdade, nem no seu histórico. Usa o .bashrc real (não uma cópia
# simplificada), então quebra se alguém mexer na lógica do hook.
#
# Confere o TOKEN gravado, não só a quantidade de linhas — a primeira versão
# deste teste só contava linhas e passou verde num hook que gravava campo
# vazio (a saída do `history` tem dois espaços entre número e comando).
#
# uso: ./bashrc_test.sh

set -u
RC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.bashrc"
FALHAS=0

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
erro() { printf '  \033[31m✗\033[0m %s\n     esperado: [%s]\n     obtido:   [%s]\n' "$1" "$2" "$3"; FALHAS=$((FALHAS+1)); }

# Roda os comandos num bash interativo com HOME isolado e devolve os tokens
# que foram parar no cmd_log.tsv, separados por vírgula.
tokens_logados() {
    local fake; fake=$(mktemp -d /tmp/bashrc_test.XXXXXX)
    mkdir -p "$fake/.local/share"
    HOME="$fake" bash --rcfile "$RC" -i >/dev/null 2>&1
    local log="$fake/.local/share/usage-tracker/cmd_log.tsv"
    if [[ -f $log ]]; then
        # campo 2 de cada linha; marca campo vazio como <VAZIO> pra ficar visível
        cut -f2 "$log" | sed 's/^$/<VAZIO>/' | paste -sd,
    fi
    rm -rf "$fake"
}

checa() { # descrição, esperado, comandos-no-stdin
    local desc=$1 esperado=$2 cmds=$3 obtido
    obtido=$(printf '%s\n' "$cmds" | tokens_logados)
    [[ $obtido == "$esperado" ]] && ok "$desc" || erro "$desc" "$esperado" "$obtido"
}

echo "bashrc_test — hook do UsageTracker"

checa "grava o primeiro token de cada comando" 'echo,ls,git' 'echo um
ls -la /tmp
git status'

checa "pipeline conta 1, e é o comando da esquerda" 'ls' 'ls | grep -c x'

checa "comando com espaço na frente não entra (ignorespace)" '' ' echo secreto'

checa "Enter vazio não entra" 'echo,echo' 'echo um

echo dois
'

checa "comando repetido conta 2 (contagem honesta)" 'echo,echo' 'echo igual
echo igual'

checa "argumentos não vazam pro token" 'grep' 'grep -rn "foo bar" /tmp'

echo
if (( FALHAS )); then
    printf '\033[31m%d falha(s)\033[0m\n' "$FALHAS"; exit 1
else
    printf '\033[32mtudo passou\033[0m\n'
fi
