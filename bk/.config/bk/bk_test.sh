#!/bin/bash
# Testes do bk. Cada caso roda num bash limpo com XDG_DATA_HOME falso;
# não toca nos bookmarks reais.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
falhas=0
ok()   { echo "  ok  $1"; }
erro() { echo "  ERRO $1"; falhas=$((falhas + 1)); }

# roda o trecho num shell novo com o bk carregado; cada caso começa sem bookmark
caso() {
    rm -rf "$TMP/data"; mkdir -p "$TMP/data" "$TMP/pasta"
    ( cd "$TMP/pasta" && XDG_DATA_HOME="$TMP/data" bash --norc --noprofile -c \
        "source '$DIR/bk.sh'; $1" 2>&1 )
}
# confere que o trecho imprime a última linha esperada
espera() {  # descrição, trecho, saída esperada na última linha
    local saida; saida="$(caso "$2" | tail -n 1)"
    [[ "$saida" == "$3" ]] && ok "$1" || erro "$1: esperava '$3', veio '$saida'"
}

echo "unbk:"
espera "remove o último bookmark" \
    'bk aa >/dev/null; unbk aa >/dev/null; bks' \
    'Nenhum bookmark salvo.'
espera "bk atualiza o único bookmark sem duplicar" \
    'bk aa >/dev/null; bk aa >/dev/null; grep -c . "$_BK_FILE"' \
    '1'
espera "remove vários e segue depois de um inexistente" \
    'bk aa >/dev/null; bk -x bb >/dev/null; unbk aa zz bb >/dev/null; echo "rc=$? $(bks)"' \
    'rc=1 Nenhum bookmark salvo.'
espera "recusa regex no nome" \
    'bk aa >/dev/null; unbk ".*" >/dev/null; bks' \
    "       \$aa                 $TMP/pasta"

echo "nomes reservados:"
for n in bk bks unbk _bk_load _BK_FILE; do
    espera "bk $n recusado e bk segue vivo" \
        "bk $n >/dev/null; bk -x $n >/dev/null; { declare -f $n || echo \"\${$n:-}\"; } | md5sum" \
        "$(caso "{ declare -f $n || echo \"\${$n:-}\"; } | md5sum")"
done
espera "unbk bk não apaga a função" \
    'unbk bk >/dev/null; type -t bk' 'function'
espera "linha reservada no arquivo é ignorada ao carregar" \
    'printf "bk\t/tmp\tx\n" >> "$_BK_FILE"; source "'"$DIR"'/bk.sh" 2>/dev/null; type bk | grep -c _bk_init' \
    '1'
espera "unbk tira linha reservada do arquivo sem unset" \
    'printf "bk\t/tmp\tx\n" >> "$_BK_FILE"; unbk bk >/dev/null; echo "$(bks) $(type -t bk)"' \
    'Nenhum bookmark salvo. function'

echo "funções que não são do bk:"
espera "bk sem -x não apaga função de mesmo nome" \
    'minha() { echo oi; }; bk minha >/dev/null; minha' 'oi'
espera "unbk de bookmark sem -x não apaga função de mesmo nome" \
    'minha() { echo oi; }; bk minha >/dev/null; unbk minha >/dev/null; minha' 'oi'
espera "bk sem -x por cima de um -x tira o atalho gerado" \
    'bk -x aa >/dev/null; bk aa >/dev/null; type -t aa || echo "sem função, \$aa=${aa:+ok}"' \
    'sem função, $aa=ok'
espera "unbk de -x tira o atalho" \
    'bk -x aa >/dev/null; unbk aa >/dev/null; type -t aa || echo some' 'some'
echo
(( falhas )) && { echo "$falhas falha(s)"; exit 1; }
echo "tudo ok"
