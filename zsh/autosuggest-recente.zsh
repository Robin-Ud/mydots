# autosuggest-recente.zsh — estratégia de autosuggestion "o mais recente".
#
# Em vez de sugerir o primeiro candidato em ordem alfabética (que é o que a
# estratégia `completion` faz), sugere o arquivo/pasta ALTERADO mais
# recentemente entre os que casam com o que você digitou.
#
# COMO DESMONTAR, do mais leve ao mais definitivo:
#   1. `recente-off`             — desliga agora, neste shell, sem reabrir nada.
#   2. ZSH_AUTOSUGGEST_STRATEGY=(completion)
#                                — volta ao comportamento anterior à estratégia.
#   3. apagar o bloco `# >>> recente` ... `# <<< recente` do .zshrc e este
#      arquivo.
#
# Contrato do plugin (zsh-autosuggestions.zsh:739): uma estratégia é uma função
# `_zsh_autosuggest_strategy_<nome>` que recebe o buffer em $1 e escreve na
# variável global `suggestion`. O plugin descarta a sugestão se ela não tiver o
# buffer como prefixo, e para na primeira estratégia que produzir algo — por
# isso `(recente completion)` funciona com a completion de fallback.

# Módulos carregados uma vez, no source — não dentro das funções. `zstat` é
# usado por _recente_mtime, que também é chamada de fora da estratégia (testes),
# e o carregamento tardio fazia ela falhar silenciosamente.
zmodload -F zsh/stat b:zstat 2>/dev/null
zmodload zsh/datetime 2>/dev/null

# zsh/files dá mkdir/mv/rm como BUILTINS (zf_*). Isso importa muito aqui: os
# comandos externos forkam um processo cada, e a estratégia roda a cada tecla —
# medido, os três forks do cache custavam ~7ms por avaliação, mais do que a
# varredura que eles deveriam estar economizando.
zmodload -F zsh/files b:zf_mkdir b:zf_mv b:zf_rm 2>/dev/null
if (( $+builtins[zf_mkdir] )); then
    _recente_mkdir() { zf_mkdir -p "$@" 2>/dev/null }
    _recente_mv()    { zf_mv -f "$@" 2>/dev/null }
    _recente_rm()    { zf_rm -f "$@" 2>/dev/null }
else
    _recente_mkdir() { command mkdir -p "$@" 2>/dev/null }
    _recente_mv()    { command mv -f "$@" 2>/dev/null }
    _recente_rm()    { command rm -f "$@" 2>/dev/null }
fi

# ---------------------------------------------------------------------------
# Configuração. Todos podem ser mudados em tempo real, sem reabrir o shell.
# ---------------------------------------------------------------------------

: ${ZSH_RECENTE_ENABLE:=1}        # 0 desliga a estratégia inteira
: ${ZSH_RECENTE_MIN_CHARS:=1}     # mínimo de caracteres na palavra atual
: ${ZSH_RECENTE_DEEP:=1}          # 1 = ranqueia pasta pelo conteúdo mais recente
: ${ZSH_RECENTE_DEEP_MAX:=5}      # só varre fundo se houver <= N candidatos
: ${ZSH_RECENTE_DEEP_BUDGET:=400} # teto de entradas no 1o nível de uma pasta
: ${ZSH_RECENTE_CACHE_TTL:=15}    # segundos de validade do cache
: ${ZSH_RECENTE_DEBUG:=0}         # 1 = loga decisões em $ZSH_RECENTE_CACHE_FILE.log
: ${ZSH_RECENTE_CACHE_FILE:=${XDG_CACHE_HOME:-$HOME/.cache}/zsh-recente}

# Pastas cuja presença no primeiro nível aborta a varredura profunda (o teste é
# barato; varrer um node_modules a cada tecla não é).
typeset -ga ZSH_RECENTE_PRUNE
(( $#ZSH_RECENTE_PRUNE )) || ZSH_RECENTE_PRUNE=(
    .git node_modules .venv venv __pycache__ target build dist .next .cache
)

# Comandos que só fazem sentido com diretório.
typeset -ga ZSH_RECENTE_DIRONLY
(( $#ZSH_RECENTE_DIRONLY )) || ZSH_RECENTE_DIRONLY=(cd pushd rmdir)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_recente_log() {
    (( ZSH_RECENTE_DEBUG )) || return 0
    print -r -- "$(strftime '%H:%M:%S' $EPOCHSECONDS) $*" \
        >> "${ZSH_RECENTE_CACHE_FILE}.log" 2>/dev/null
}

# Lê o mtime cacheado de um diretório. Sucesso => $REPLY tem o valor.
# O cache PRECISA ser em arquivo: em modo async o plugin roda a estratégia num
# subshell forkado (zsh-autosuggestions.zsh:793), então variável global morre
# junto com o fork e não sobrevive entre teclas.
_recente_cache_get() {
    local dir=$1 agora=$EPOCHSECONDS
    local ts val alvo
    [[ -r "$ZSH_RECENTE_CACHE_FILE" ]] || return 1
    # formato: <epoch da gravação><TAB><mtime><TAB><dir>
    # NB: a variável de destino NÃO pode se chamar `path` — em zsh `path` é
    # array especial amarrado ao $PATH, e escrever nele detona o PATH do shell.
    # (mesmo tipo de acidente que o `bk PATH` causa)
    while IFS=$'\t' read -r ts val alvo; do
        [[ "$alvo" == "$dir" ]] || continue
        (( agora - ts > ZSH_RECENTE_CACHE_TTL )) && return 1
        typeset -g REPLY=$val
        return 0
    done < "$ZSH_RECENTE_CACHE_FILE"
    return 1
}

_recente_cache_put() {
    local dir=$1 val=$2 tmp="${ZSH_RECENTE_CACHE_FILE}.$$"
    local corte=$(( EPOCHSECONDS - ZSH_RECENTE_CACHE_TTL ))
    local dircache=${ZSH_RECENTE_CACHE_FILE:h}
    [[ -d "$dircache" ]] || _recente_mkdir "$dircache" || return
    {
        # mantém só entradas ainda válidas e de outros diretórios
        if [[ -r "$ZSH_RECENTE_CACHE_FILE" ]]; then
            local ts v p   # `p`, não `path` — ver nota em _recente_cache_get
            while IFS=$'\t' read -r ts v p; do
                [[ "$p" == "$dir" ]] && continue
                (( ts < corte )) && continue
                printf '%s\t%s\t%s\n' "$ts" "$v" "$p"
            done < "$ZSH_RECENTE_CACHE_FILE"
        fi
        printf '%s\t%s\t%s\n' "$EPOCHSECONDS" "$val" "$dir"
    } > "$tmp" 2>/dev/null && _recente_mv "$tmp" "$ZSH_RECENTE_CACHE_FILE"
    [[ -e "$tmp" ]] && _recente_rm "$tmp"
}

# mtime efetivo de um candidato.
# Arquivo   -> o próprio mtime.
# Diretório -> mtime do descendente mais recente, porque o mtime de uma pasta só
#              muda quando entradas são criadas/apagadas/renomeadas nela; editar
#              um arquivo lá dentro não conta. (Medido: ~/obsidian/5 facul com
#              mtime de 08/07 mas conteúdo de 10/07.)
# Cai de volta no mtime raso quando a subárvore é podada ou grande demais.
_recente_mtime() {
    emulate -L zsh
    setopt EXTENDED_GLOB NULL_GLOB
    local alvo=$1
    local -a st

    zstat -A st +mtime "$alvo" 2>/dev/null || return 1
    typeset -g REPLY=$st[1]

    [[ -d "$alvo" ]] || return 0
    (( ZSH_RECENTE_DEEP )) || return 0

    local abs=${alvo:A}
    if _recente_cache_get "$abs"; then
        _recente_log "cache hit  $abs"
        return 0
    fi

    # poda barata: se o primeiro nível tem pasta pesada, nem começa
    local -a pesadas
    pesadas=( "$alvo"/${^ZSH_RECENTE_PRUNE}(N/) )
    if (( $#pesadas )); then
        _recente_log "podado     $abs (${pesadas[1]:t})"
        _recente_cache_put "$abs" "$REPLY"
        return 0
    fi

    # teto de largura: pasta com primeiro nível enorme (cache, downloads, dumps)
    # provavelmente tem subárvore cara. É um proxy barato — conta um nível só,
    # sem descer. Contar a árvore inteira custaria a mesma varredura que a gente
    # quer evitar.
    local -a nivel1
    nivel1=( "$alvo"/*(N) )
    if (( $#nivel1 > ZSH_RECENTE_DEEP_BUDGET )); then
        _recente_log "largo      $abs ($#nivel1 no 1o nivel)"
        _recente_cache_put "$abs" "$REPLY"
        return 0
    fi

    # UMA varredura só: o zsh ordena por mtime e [1] pega o mais recente.
    # (antes eram duas — uma pra contar, outra pra ordenar — e isso dobrava o
    # custo em árvore grande: ~/deving caiu de 33ms pra metade com essa mudança)
    local -a novo
    novo=( "$alvo"/**/*(N.om[1]) )
    if (( $#novo )); then
        zstat -A st +mtime "$novo[1]" 2>/dev/null \
            && (( st[1] > REPLY )) && REPLY=$st[1]
    fi
    _recente_log "fundo      $abs -> $REPLY"
    _recente_cache_put "$abs" "$REPLY"
    return 0
}

# ---------------------------------------------------------------------------
# A estratégia
# ---------------------------------------------------------------------------

_zsh_autosuggest_strategy_recente() {
    emulate -L zsh
    setopt EXTENDED_GLOB NULL_GLOB

    typeset -g suggestion
    unset suggestion

    (( ZSH_RECENTE_ENABLE )) || return

    local buf=$1
    [[ -z "$buf" || "$buf" == *[[:space:]] ]] && return   # palavra atual vazia

    local -a words
    words=(${(z)buf})
    (( $#words < 2 )) && return          # posição de comando: deixa pra completion

    local digitado=${words[-1]}
    (( ${#digitado} < ZSH_RECENTE_MIN_CHARS )) && return

    # A palavra chega como o usuário digitou, ou seja ESCAPADA: `5\ facul`.
    # ${(Q)} tira um nível de quoting pra virar o nome real (`5 facul`) antes
    # de globbar — sem isso a barra invertida entra no padrão como caractere
    # literal e não casa com nada. Depois expande ~ à mão.
    # A sugestão é remontada em cima do buffer original, senão o plugin
    # descarta por não bater o prefixo.
    local busca=${(Q)digitado}
    [[ "$busca" == '~'* ]] && busca=${busca/#\~/$HOME}

    # `cd`/`pushd` só aceitam diretório
    local qual='N'
    (( ${ZSH_RECENTE_DIRONLY[(Ie)${words[1]}]} )) && qual='N/'

    local -a cands
    cands=( ${busca}*(${~qual}) )
    (( $#cands )) || return

    local escolhido=$cands[1]
    if (( $#cands > 1 )); then
        if (( $#cands > ZSH_RECENTE_DEEP_MAX )); then
            # candidatos demais para varrer fundo: ordena pelo mtime raso
            cands=( ${busca}*(${~qual}om) )
            escolhido=$cands[1]
            _recente_log "raso       '$digitado' ($#cands candidatos)"
        else
            local melhor=-1 c
            for c in $cands; do
                _recente_mtime "$c" || continue
                (( REPLY > melhor )) && { melhor=$REPLY; escolhido=$c }
            done
        fi
    else
        _recente_mtime "$escolhido" 2>/dev/null
    fi

    [[ -d "$escolhido" ]] && escolhido+=/

    # devolve o sufixo, preservando exatamente o que o usuário digitou
    local sufixo=${escolhido#$busca}
    suggestion="${buf}${(q)sufixo}"
    _recente_log "sugere     '$buf' -> '$suggestion'"
}

# ---------------------------------------------------------------------------
# Conveniência
# ---------------------------------------------------------------------------

recente-on()  { ZSH_RECENTE_ENABLE=1; print "recente: ligado"; }
recente-off() { ZSH_RECENTE_ENABLE=0; print "recente: desligado (completion assume)"; }

recente-status() {
    local v nome
    print "estrategia     : ${ZSH_AUTOSUGGEST_STRATEGY[*]}"
    for v in ENABLE MIN_CHARS DEEP DEEP_MAX DEEP_BUDGET CACHE_TTL DEBUG; do
        nome=ZSH_RECENTE_$v
        printf "%-15s: %s\n" "$v" "${(P)nome}"
    done
    printf "%-15s: %s\n" "PRUNE" "${ZSH_RECENTE_PRUNE[*]}"
    printf "%-15s: %s\n" "CACHE_FILE" "$ZSH_RECENTE_CACHE_FILE"
    if [[ -r "$ZSH_RECENTE_CACHE_FILE" ]]; then
        printf "%-15s: %s entradas\n" "cache" "$(wc -l < "$ZSH_RECENTE_CACHE_FILE")"
    fi
}

recente-clear() { rm -f "$ZSH_RECENTE_CACHE_FILE" "${ZSH_RECENTE_CACHE_FILE}.log"; print "cache limpo"; }
