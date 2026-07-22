#!/usr/bin/env zsh
# Testes da estratégia `recente`. Roda a função direto, sem zle e sem tocar no
# shell interativo — dá pra mexer no autosuggest-recente.zsh e validar aqui
# antes de abrir um terminal.
#
#   zsh autosuggest-recente-test.zsh          # casos PASS/FAIL
#   zsh autosuggest-recente-test.zsh --bench  # custo por sugestão

emulate -L zsh
setopt EXTENDED_GLOB NULL_GLOB
zmodload zsh/datetime

ESTRATEGIA=${0:A:h}/autosuggest-recente.zsh
[[ -r "$ESTRATEGIA" ]] || { print -u2 "não achei $ESTRATEGIA"; exit 1 }

SANDBOX=$(mktemp -d -t recente-test.XXXXXX)
export ZSH_RECENTE_CACHE_FILE="$SANDBOX/.cache"
source "$ESTRATEGIA"

trap 'rm -rf "$SANDBOX"' EXIT INT TERM

# --------------------------------------------------------------------------
# Sandbox: cada caso com mtime controlado
# --------------------------------------------------------------------------
montar() {
    cd "$SANDBOX"

    # pastas com espaço no nome, como no vault do obsidian.
    # "5 facul" tem mtime ANTIGO mas conteúdo NOVO -> só a varredura profunda
    # acerta. É exatamente a defasagem medida no vault real.
    mkdir -p "5 facul/sub" "5 nutricao"
    echo velho > "5 nutricao/nota.md"
    echo novo  > "5 facul/sub/aula.md"
    touch -d "2026-07-18 10:00" "5 facul/sub/aula.md"
    touch -d "2026-07-01 10:00" "5 nutricao/nota.md" "5 nutricao"
    touch -d "2026-01-01 10:00" "5 facul" "5 facul/sub"

    # arquivos soltos: o mais recente deve ganhar
    echo a > nota01.md; echo b > nota02.md
    touch -d "2026-07-01 10:00" nota01.md
    touch -d "2026-07-18 10:00" nota02.md

    # pasta que deve ser PODADA (node_modules no primeiro nível)
    mkdir -p "pesada/node_modules/x"
    echo y > "pesada/node_modules/x/lixo.js"
    touch -d "2026-07-19 10:00" "pesada/node_modules/x/lixo.js"
    touch -d "2026-01-01 10:00" "pesada"

    # pasta leve e recente, pra concorrer com a podada
    mkdir -p "pesadinha"
    echo z > "pesadinha/ok.txt"
    touch -d "2026-07-02 10:00" "pesadinha/ok.txt" "pesadinha"

    mkdir -p soqueeu
}

# --------------------------------------------------------------------------
# Runner
# --------------------------------------------------------------------------
ok=0; falhou=0

checa() {
    local desc=$1 buffer=$2 esperado=$3
    suggestion=''
    _zsh_autosuggest_strategy_recente "$buffer"
    local got=${suggestion:-'(nada)'}
    if [[ "$got" == "$esperado" ]]; then
        printf '  \e[32mPASS\e[0m  %-34s %s\n' "$desc" "[$buffer] -> $got"
        (( ok++ ))
    else
        printf '  \e[31mFAIL\e[0m  %-34s [%s]\n        esperado: %s\n        obtido:   %s\n' \
            "$desc" "$buffer" "$esperado" "$got"
        (( falhou++ ))
    fi
}

# --------------------------------------------------------------------------
# Bench
# --------------------------------------------------------------------------
if [[ "$1" == --bench ]]; then
    montar
    print "custo por sugestao (media de 100, cache quente):\n"
    bench() {
        local dir=$1 buf=$2 n=100 t0
        cd "$dir" 2>/dev/null || { printf '  %-38s (nao existe)\n' "$dir"; return }
        suggestion=''; _zsh_autosuggest_strategy_recente "$buf"   # aquece
        t0=$EPOCHREALTIME
        repeat $n; do suggestion=''; _zsh_autosuggest_strategy_recente "$buf"; done
        printf '  %-24s %-12s %6.2f ms\n' "${dir/#$HOME/~}" "[$buf]" \
            $(( (EPOCHREALTIME - t0) * 1000 / n ))
    }
    bench "$SANDBOX"    "cd 5"
    bench "$SANDBOX"    "cd pesa"
    bench "$HOME"       "cd d"
    bench "$HOME"       "nvim .z"
    [[ -d ~/obsidian ]] && bench ~/obsidian "cd 5"
    [[ -d ~/deving   ]] && bench ~/deving   "cd "$'\052'
    print "\nsem cache (recalculando toda vez):"
    ZSH_RECENTE_CACHE_TTL=0 bench "$SANDBOX" "cd 5"
    [[ -d ~/obsidian ]] && ZSH_RECENTE_CACHE_TTL=0 bench ~/obsidian "cd 5"
    exit 0
fi

# --------------------------------------------------------------------------
# Casos
# --------------------------------------------------------------------------
montar
cd "$SANDBOX"

print "sandbox: $SANDBOX\n"

checa "gate: palavra vazia"          "cd "        "(nada)"
checa "gate: buffer vazio"           ""           "(nada)"
checa "posicao de comando"           "cd"         "(nada)"
checa "sem candidato"                "cd zzz"     "(nada)"

checa "arquivo mais recente"         "nvim nota"  "nvim nota02.md"
checa "pasta: conteudo mais recente" "cd 5"       "cd 5\\ facul/"
# espaço ESCAPADO continua a mesma palavra e deve casar.
# Espaço SEM escape é outra palavra pro shell (`cd 5 f` = dois argumentos),
# então não sugerir ali é o comportamento certo, não um bug.
checa "espaco escapado casa"         'cd 5\ f'    'cd 5\ facul/'
checa "espaco sem escape: ignora"    "cd 5 f"     "(nada)"
checa "unico candidato"              "cd soq"     "cd soqueeu/"

checa "cd ignora arquivo"            "cd nota"    "(nada)"
checa "nvim aceita pasta"            "nvim soq"   "nvim soqueeu/"

# node_modules deve ser podado: "pesada" fica com mtime raso (01/01) e perde
# para "pesadinha" (02/07), mesmo tendo arquivo de 19/07 lá dentro.
checa "poda node_modules"            "cd pesa"    "cd pesadinha/"

# min_chars
ZSH_RECENTE_MIN_CHARS=3 checa "min_chars=3 bloqueia"  "cd 5"    "(nada)"
ZSH_RECENTE_MIN_CHARS=3 checa "min_chars=3 libera"    "nvim nota" "nvim nota02.md"

# desligado
ZSH_RECENTE_ENABLE=0 checa "ENABLE=0 nao sugere"      "nvim nota" "(nada)"

# deep off: "5 facul" volta a ser julgada pelo mtime raso (01/01) e perde
ZSH_RECENTE_DEEP=0 checa "DEEP=0 usa mtime raso"      "cd 5"    "cd 5\\ nutricao/"

# expansao de ~ (o sufixo devolvido tem que casar com o que foi digitado)
cd /
checa "expande ~ no prefixo"  "nvim ~/.zshr"  "nvim ~/.zshrc"

print ""
if (( falhou )); then
    printf '\e[31m%d falhou\e[0m, %d passou\n' $falhou $ok
    exit 1
else
    printf '\e[32mtudo passou\e[0m (%d casos)\n' $ok
fi
