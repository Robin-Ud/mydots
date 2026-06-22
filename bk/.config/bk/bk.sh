#!/usr/bin/env bash
# bk.sh — sistema de bookmarks de diretório
# source este arquivo no ~/.bashrc ou ~/.zshrc:
#   [[ -f ~/.config/bk/bk.sh ]] && source ~/.config/bk/bk.sh

_BK_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/bk/bookmarks"

_bk_init() {
    mkdir -p "$(dirname "$_BK_FILE")"
    [[ -f "$_BK_FILE" ]] || touch "$_BK_FILE"
}

# Carregado ao sourcear: exporta variáveis e define funções -x
_bk_load() {
    _bk_init
    while IFS=$'\t' read -r name path flags; do
        [[ -z "$name" ]] && continue
        if [[ ! "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            echo "bk: nome inválido '$name' no arquivo de bookmarks — use letras, números e _. Ignorando essa linha (use 'unbk' ou edite ~/.local/share/bk/bookmarks)." >&2
            continue
        fi
        unalias "$name" 2>/dev/null
        export "${name}=${path}"
        if [[ "$flags" == *x* ]]; then
            eval "${name}() { if [ \$# -eq 0 ]; then cd \"\$${name}\"; elif [ \"\$1\" = cld ]; then cd \"\$${name}\" && claude; else \"\$@\" \"\$${name}\"; fi; }"
        fi
    done < "$_BK_FILE"
}

bk() {
    local dangerous=0 name=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -x)        dangerous=1; shift ;;
            --help|-h) _bk_help; return 0 ;;
            -*)        echo "bk: opção desconhecida: $1"; return 1 ;;
            *)         name="$1"; shift ;;
        esac
    done

    if [[ -z "$name" ]]; then
        echo "Uso: bk [-x] <nome>"
        return 1
    fi
    if [[ ! "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "bk: nome inválido '$name' — use letras, números e _"
        return 1
    fi

    if (( dangerous )); then
        local existing_type
        existing_type=$(type -t "$name" 2>/dev/null)
        case "$existing_type" in
            builtin|keyword|file)
                echo "bk: conflito — '$name' é um $existing_type do sistema. Use bk sem -x para variável."
                return 1
                ;;
            function|alias)
                if ! grep -q "^${name}"$'\t' "$_BK_FILE" 2>/dev/null; then
                    echo "bk: conflito — '$name' já é um $existing_type não gerado por bk."
                    return 1
                fi
                ;;
        esac
    fi

    local path flags_val=""
    path="$(pwd)"
    (( dangerous )) && flags_val="x"

    _bk_init
    local existed=0
    if grep -q "^${name}"$'\t' "$_BK_FILE" 2>/dev/null; then
        existed=1
        grep -v "^${name}"$'\t' "$_BK_FILE" > "${_BK_FILE}.tmp" && mv "${_BK_FILE}.tmp" "$_BK_FILE"
    fi
    printf '%s\t%s\t%s\n' "$name" "$path" "$flags_val" >> "$_BK_FILE"

    export "${name}=${path}"
    if (( dangerous )); then
        eval "${name}() { if [ \$# -eq 0 ]; then cd \"\$${name}\"; elif [ \"\$1\" = cld ]; then cd \"\$${name}\" && claude; else \"\$@\" \"\$${name}\"; fi; }"
    else
        unset -f "$name" 2>/dev/null
    fi

    (( existed )) && echo "Atualizado: \$$name → $path" || echo "Salvo: \$$name → $path"
}

bks() {
    case "$1" in
        verify) _bks_verify; return ;;
    esac

    _bk_init
    if [[ ! -s "$_BK_FILE" ]]; then
        echo "Nenhum bookmark salvo."
        return 0
    fi
    while IFS=$'\t' read -r name path flags; do
        [[ -z "$name" ]] && continue
        local marker="    "
        [[ "$flags" == *x* ]] && marker="[-x]"
        printf "  %s \$%-18s %s\n" "$marker" "$name" "${path/#$HOME/\~}"
    done < "$_BK_FILE"
}

_bks_verify() {
    _bk_init
    local found=0
    while IFS=$'\t' read -r name path flags; do
        [[ -z "$name" || "$flags" != *x* ]] && continue
        local existing_type
        existing_type=$(type -t "$name" 2>/dev/null)
        [[ "$existing_type" != "file" ]] && continue

        found=1
        local cmd_path
        cmd_path=$(command -v "$name")
        printf '\n  [!] \033[1m%s\033[0m — conflito com comando: %s\n' "$name" "$cmd_path"
        printf '      bookmark aponta para: %s\n' "$path"
        printf '      [d] excluir  [r] renomear  [s] pular: '
        read -r choice </dev/tty
        case "$choice" in
            d)
                grep -v "^${name}"$'\t' "$_BK_FILE" > "${_BK_FILE}.tmp" && mv "${_BK_FILE}.tmp" "$_BK_FILE"
                unset "$name"; unset -f "$name" 2>/dev/null
                echo "      Removido: $name"
                ;;
            r)
                printf '      Novo nome: '
                read -r new_name </dev/tty
                if [[ ! "$new_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                    echo "      Nome inválido, pulando."
                else
                    grep -v "^${name}"$'\t' "$_BK_FILE" > "${_BK_FILE}.tmp" && mv "${_BK_FILE}.tmp" "$_BK_FILE"
                    printf '%s\t%s\t%s\n' "$new_name" "$path" "$flags" >> "$_BK_FILE"
                    unset "$name"; unset -f "$name" 2>/dev/null
                    export "${new_name}=${path}"
                    eval "${new_name}() { if [ \$# -eq 0 ]; then cd \"\$${new_name}\"; elif [ \"\$1\" = cld ]; then cd \"\$${new_name}\" && claude; else \"\$@\" \"\$${new_name}\"; fi; }"
                    echo "      Renomeado: $name → $new_name"
                fi
                ;;
            *) echo "      Pulado." ;;
        esac
    done < "$_BK_FILE"

    (( found )) || echo "Nenhum conflito encontrado nos bookmarks -x."
    echo ""
}

unbk() {
    local name="$1"
    if [[ -z "$name" ]]; then
        echo "Uso: unbk <nome>"
        return 1
    fi
    _bk_init
    if grep -q "^${name}"$'\t' "$_BK_FILE" 2>/dev/null; then
        grep -v "^${name}"$'\t' "$_BK_FILE" > "${_BK_FILE}.tmp" && mv "${_BK_FILE}.tmp" "$_BK_FILE"
        unset "$name"; unset -f "$name" 2>/dev/null
        echo "Removido: \$$name"
    else
        echo "unbk: não encontrado: $name"
        return 1
    fi
}

_bk_help() {
    cat <<'EOF'

  bk <nome>         salva $nome=/pasta/atual no .bashrc
                    use como variável: cd $nome, ls $nome, cat $nome/arquivo, etc.
  bk -x <nome>      modo estendido: nome → cd; nome ls, nome rm -rf, nome cld, etc.
                    nome cld → cd e abre o claude
  bks               lista todos os bookmarks
  bks verify        verifica conflitos nos bookmarks -x (installs novos)
  unbk <nome>       remove um bookmark
  bk --help         mostra esta ajuda

EOF
}

_bk_load
