#!/usr/bin/env bash
# settempcom.sh — comandos temporários com prazo de validade
# source no ~/.bashrc:
#   [[ -f ~/.config/bash/settempcom.sh ]] && source ~/.config/bash/settempcom.sh
#
# Cada comando vira uma função que vale em todo terminal novo até expirar.
# Formato do arquivo: nome<TAB>expira_epoch<TAB>comando

_STC_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/settempcom/cmds"
_STC_BK_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/bk/bookmarks"
_STC_NAMES=()   # nomes que ESTA shell definiu — pra saber que a função é nossa

_stc_init() {
    mkdir -p "$(dirname "$_STC_FILE")"
    [[ -f "$_STC_FILE" ]] || touch "$_STC_FILE"
}

_stc_has() { grep -q "^${1}"$'\t' "$_STC_FILE" 2>/dev/null; }

_stc_drop() {
    grep -v "^${1}"$'\t' "$_STC_FILE" > "${_STC_FILE}.tmp"
    mv "${_STC_FILE}.tmp" "$_STC_FILE"
}

_stc_type() {
    if declare -F _bk_type >/dev/null; then _bk_type "$1"; else type -t "$1" 2>/dev/null; fi
}

_stc_ours() {
    local n
    for n in "${_STC_NAMES[@]}"; do [[ "$n" == "$1" ]] && return 0; done
    return 1
}

# Imprime o motivo do conflito (vazio = nome livre). Mesmas regras do `bk -x`,
# mais a checagem cruzada com os bookmarks -x (mesmo os ainda não carregados).
# $2=update: função/alias já registrado no SetTempCommand não conta como conflito.
_stc_conflict() {
    local name="$1" mode="$2" t
    t=$(_stc_type "$name")
    case "$t" in
        builtin|keyword|file)
            if [[ "$t" == file ]]; then echo "'$name' é um comando do sistema ($(type -P "$name"))"
            else echo "'$name' é um $t do shell"; fi
            return ;;
        function|alias)
            if ! { _stc_ours "$name" || { [[ "$mode" == update ]] && _stc_has "$name"; }; }; then
                echo "'$name' já é um $t não gerado pelo SetTempCommand"
                return
            fi ;;
    esac
    if [[ -f "$_STC_BK_FILE" ]] && awk -F'\t' -v n="$name" '$1==n && $3 ~ /x/ {f=1} END {exit !f}' "$_STC_BK_FILE"; then
        echo "'$name' é um bookmark bk -x"
    fi
}

_stc_dur() {
    [[ "$1" =~ ^([0-9]+)([mhdw]?)$ ]] || return 1
    local n=${BASH_REMATCH[1]} u=${BASH_REMATCH[2]:-d}
    case "$u" in
        m) echo $(( n * 60 )) ;;
        h) echo $(( n * 3600 )) ;;
        d) echo $(( n * 86400 )) ;;
        w) echo $(( n * 604800 )) ;;
    esac
}

_stc_left() {
    local s=$(( $1 - $(date +%s) ))
    if   (( s >= 86400 )); then echo "$(( s / 86400 ))d $(( s % 86400 / 3600 ))h"
    elif (( s >= 3600 ));  then echo "$(( s / 3600 ))h $(( s % 3600 / 60 ))m"
    else echo "$(( s / 60 ))m"; fi
}

_stc_define() {
    eval "${1}() { ${2}
}"
    _stc_ours "$1" || _STC_NAMES+=("$1")
}

_stc_undefine() {
    unset -f "$1" 2>/dev/null
    local i
    for i in "${!_STC_NAMES[@]}"; do [[ "${_STC_NAMES[$i]}" == "$1" ]] && unset '_STC_NAMES[i]'; done
}

# Carregado ao sourcear: apaga os vencidos, define os válidos que não colidem.
_stc_load() {
    _stc_init
    local now name exp cmd why keep=() warned=0
    now=$(date +%s)
    # re-source do .bashrc: esquece o que já definimos pra checar do zero
    for name in "${_STC_NAMES[@]}"; do unset -f "$name" 2>/dev/null; done
    _STC_NAMES=()

    while IFS=$'\t' read -r name exp cmd; do
        [[ -z "$name" ]] && continue
        if [[ ! "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ || ! "$exp" =~ ^[0-9]+$ ]]; then
            echo "SetTempCommand: linha inválida '$name' em $_STC_FILE — ignorando." >&2
            continue
        fi
        (( exp <= now )) && continue          # vencido: some do arquivo
        keep+=("$name"$'\t'"$exp"$'\t'"$cmd")
        why=$(_stc_conflict "$name")
        if [[ -n "$why" ]]; then
            echo "SetTempCommand: '$name' não carregado — $why. Rode 'SetTempCommand verify'." >&2
            warned=1
            continue
        fi
        _stc_define "$name" "$cmd"
    done < "$_STC_FILE"

    if (( ${#keep[@]} )); then printf '%s\n' "${keep[@]}"; fi > "${_STC_FILE}.tmp"
    mv "${_STC_FILE}.tmp" "$_STC_FILE"
}

_stc_list() {
    _stc_init
    if [[ ! -s "$_STC_FILE" ]]; then
        echo "Nenhum comando temporário."
        return 0
    fi
    local name exp cmd now marker
    now=$(date +%s)
    while IFS=$'\t' read -r name exp cmd; do
        [[ -z "$name" ]] && continue
        (( exp <= now )) && continue
        marker="   "
        _stc_ours "$name" || marker="[!]"   # registrado mas não carregado (conflito)
        printf "  %s %-16s %-8s %s\n" "$marker" "$name" "$(_stc_left "$exp")" "$cmd"
    done < "$_STC_FILE"
}

_stc_remove() {
    local name="$1"
    if [[ -z "$name" ]]; then
        echo "Uso: SetTempCommand -r <nome>"
        return 1
    fi
    _stc_init
    if _stc_has "$name"; then
        _stc_drop "$name"
        _stc_ours "$name" && _stc_undefine "$name"
        echo "Removido: $name"
    else
        echo "SetTempCommand: não encontrado: $name"
        return 1
    fi
}

_stc_verify() {
    _stc_init
    local name exp cmd why choice new_name found=0 now
    now=$(date +%s)
    # lê numa cópia: o loop mexe no arquivo
    local lines=()
    mapfile -t lines < "$_STC_FILE"
    local line
    for line in "${lines[@]}"; do
        IFS=$'\t' read -r name exp cmd <<< "$line"
        [[ -z "$name" ]] && continue
        (( exp <= now )) && continue
        # tira o nosso de cena pra enxergar o que está por baixo
        local was_ours=0
        _stc_ours "$name" && was_ours=1
        _stc_undefine "$name"
        why=$(_stc_conflict "$name")
        if [[ -z "$why" ]]; then
            _stc_define "$name" "$cmd"
            (( was_ours )) || echo "  $name agora está livre — carregado."
            continue
        fi

        found=1
        printf '\n  [!] \033[1m%s\033[0m — conflito: %s\n' "$name" "$why"
        printf '      comando: %s\n' "$cmd"
        printf '      [d] excluir  [r] renomear  [s] pular: '
        read -r choice </dev/tty
        case "$choice" in
            d)
                _stc_drop "$name"
                echo "      Removido: $name"
                ;;
            r)
                printf '      Novo nome: '
                read -r new_name </dev/tty
                if [[ ! "$new_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                    echo "      Nome inválido, pulando."
                elif _stc_has "$new_name"; then
                    echo "      '$new_name' já é outro comando temporário, pulando."
                elif why=$(_stc_conflict "$new_name"); [[ -n "$why" ]]; then
                    echo "      Conflito: $why — pulando."
                else
                    _stc_drop "$name"
                    printf '%s\t%s\t%s\n' "$new_name" "$exp" "$cmd" >> "$_STC_FILE"
                    _stc_define "$new_name" "$cmd"
                    echo "      Renomeado: $name → $new_name"
                fi
                ;;
            *) echo "      Pulado." ;;
        esac
    done

    (( found )) || echo "Nenhum conflito encontrado nos comandos temporários."
    echo ""
}

_stc_help() {
    cat <<'EOF'

  SetTempCommand [-d DUR] <nome> '<comando>'
                        cria a função <nome> que roda <comando>, válida em todo
                        terminal novo até expirar. DUR: 5 (dias), 30m, 3h, 2d, 1w.
                        Sem -d: 1 dia. Mesmo nome de novo → atualiza comando e prazo.
  SetTempCommand -l     lista os ativos e quanto falta ([!] = não carregado, conflito)
  SetTempCommand -r <nome>   remove antes do prazo
  SetTempCommand verify      revisa conflitos com comandos/bookmarks novos
  SetTempCommand -h, --help  mostra esta ajuda

  Ex.: SetTempCommand -d 5 pomba 'cd ~/deving/pombaieira && xdg-open index.html'

EOF
}

SetTempCommand() {
    local dur="1" name="" cmd="" secs
    case "$1" in
        verify)    _stc_verify; return ;;
        -l)        _stc_list; return ;;
        -r)        _stc_remove "$2"; return ;;
        --help|-h) _stc_help; return 0 ;;
    esac
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d)  dur="$2"; shift 2 ;;
            -h|--help) _stc_help; return 0 ;;
            -*)  echo "SetTempCommand: opção desconhecida: $1"; return 1 ;;
            *)
                if   [[ -z "$name" ]]; then name="$1"
                elif [[ -z "$cmd" ]];  then cmd="$1"
                else echo "SetTempCommand: argumento sobrando: '$1' — ponha o comando entre aspas."; return 1
                fi
                shift ;;
        esac
    done

    if [[ -z "$name" || -z "$cmd" ]]; then
        echo "Uso: SetTempCommand [-d DUR] <nome> '<comando>'   (SetTempCommand -h)"
        return 1
    fi
    if ! secs=$(_stc_dur "$dur"); then
        echo "SetTempCommand: duração inválida '$dur' — use 5, 30m, 3h, 2d, 1w"
        return 1
    fi
    if [[ ! "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "SetTempCommand: nome inválido '$name' — use letras, números e _"
        return 1
    fi
    if [[ "$cmd" == *$'\t'* || "$cmd" == *$'\n'* ]]; then
        echo "SetTempCommand: o comando não pode ter TAB nem quebra de linha — use ';' ou '&&'"
        return 1
    fi
    # valida a sintaxe antes de gravar: um comando quebrado no arquivo
    # derrubaria o eval de todo terminal novo
    if ! bash -n <<< "_stc_probe() { ${cmd}
}" 2>/dev/null; then
        echo "SetTempCommand: erro de sintaxe no comando: $cmd"
        return 1
    fi

    _stc_init
    local why
    why=$(_stc_conflict "$name" update)
    if [[ -n "$why" ]]; then
        echo "SetTempCommand: conflito — $why."
        return 1
    fi

    local exp existed=0
    exp=$(( $(date +%s) + secs ))
    if _stc_has "$name"; then
        existed=1
        _stc_drop "$name"
    fi
    printf '%s\t%s\t%s\n' "$name" "$exp" "$cmd" >> "$_STC_FILE"
    _stc_define "$name" "$cmd"

    (( existed )) && printf 'Atualizado: ' || printf 'Salvo: '
    echo "$name → válido até $(date -d "@$exp" '+%d/%m %H:%M') ($(_stc_left "$exp"))"
}

_stc_load
