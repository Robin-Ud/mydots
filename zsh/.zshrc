# .zshrc — port experimental do .bashrc, com Oh My Zsh.
# Gerado pra comparar bash/zsh/fish. Pra remover: rm -rf ~/.oh-my-zsh ~/.zshrc ~/.zcompdump*

# ===========================================================
# 0. OH MY ZSH — framework, autosuggestions, syntax highlighting
# ===========================================================

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""   # vazio: quem cuida do prompt é o starship (ver final do arquivo)
plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions fzf)

# >>> recente ---------------------------------------------------------------
# Autosuggestion. O padrão do plugin é a estratégia `history`, que é cega ao
# diretório: oferece comandos antigos (arquivo de outra pasta, subdir que não
# existe aqui). `completion` usa o motor real de completion e só sugere o que
# existe de fato; `recente` (nossa, em autosuggest-recente.zsh) vai além e
# escolhe o candidato ALTERADO mais recentemente em vez do primeiro em ordem
# alfabética, olhando o conteúdo das pastas.
#
# EXPERIMENTAL (19/07). Para desmontar, do mais leve ao mais definitivo:
#   1. `recente-off`                          — desliga agora, sem reabrir nada
#   2. ZSH_AUTOSUGGEST_STRATEGY=(completion)  — volta ao comportamento anterior
#   3. apagar deste marcador até o `# <<< recente`, mais o arquivo
# `recente-status` mostra a configuração em vigor; `recente-clear` limpa o cache.
source ~/.mydots/zsh/autosuggest-recente.zsh
ZSH_AUTOSUGGEST_STRATEGY=(recente completion)

# Gate: não sugere enquanto a palavra ATUAL estiver vazia (buffer vazio ou
# terminando em espaço). A partir do 1º caractere digitado, sugere.
# Isso evita a sugestão gratuita logo após `cd ` / `nvim `, que era o barulho.
# Vale só para a estratégia `completion`; a `recente` tem o seu próprio
# (ZSH_RECENTE_MIN_CHARS), mantido em sincronia.
# Para exigir 2+ caracteres: '(|*[[:space:]])[^[:space:]](#c0,1)'
ZSH_AUTOSUGGEST_COMPLETION_IGNORE='*[[:space:]]|'

# Ambas as estratégias rodam a cada tecla; async evita engasgo na digitação.
ZSH_AUTOSUGGEST_USE_ASYNC=1
# <<< recente ---------------------------------------------------------------

source "$ZSH/oh-my-zsh.sh"
# ↑ o plugin `fzf` do OMZ já cuida do key-bindings (Ctrl+R/Ctrl+T/Alt+C) —
#   por isso NÃO sourceamos /usr/share/fzf/shell/key-bindings.zsh manualmente
#   (duplicaria os binds).

# ===========================================================
# 1. SISTEMA — configurações globais e PATH
# ===========================================================

if ! [[ "$PATH" =~ "$HOME/.local/bin:" ]]; then
    PATH="$HOME/.local/bin:$PATH"
fi
export PATH

export EDITOR=nvim

export NPM_CONFIG_USERCONFIG="$HOME/.config/npm/npmrc"
export NPM_CONFIG_CACHE="$HOME/.cache/npm"

export FZF_DEFAULT_OPTS="--preview 'bat --color=always {}'"

# ===========================================================
# 2. ALIASES
# ===========================================================

alias pt='pytest -xv test.py'
alias :q='exit'
alias code='code .'
alias colheita='~/deving/colheita/colheita.sh'

# ===========================================================
# 3. FUNÇÕES (idênticas ao .bashrc — zsh entende a mesma sintaxe)
# ===========================================================

# wiki do Hyprland offline (espelhada por ~/hyprland-wiki-0.51.0/mirror_wiki.py)
hyprwiki() {
    local porta=8631
    if ! curl -s -o /dev/null "http://localhost:$porta/0.51.0/"; then
        (cd ~/hyprland-wiki-0.51.0 && python3 -m http.server "$porta" &>/dev/null &)
        sleep 0.5
    fi
    xdg-open "http://localhost:$porta/0.51.0/"
}

verificar_uptime() {
    local DIAS_LIMITE=1
    local HORAS_SONECA=2
    local ARQUIVO_SONECA="$HOME/.cache/soneca_reboot_time"

    local UPTIME_SEG
    UPTIME_SEG=$(cut -d. -f1 /proc/uptime)
    local UPTIME_DIAS=$(( UPTIME_SEG / 86400 ))

    local AGORA
    AGORA=$(date +%s)
    local PROXIMA_PERGUNTA
    PROXIMA_PERGUNTA=$(cat "$ARQUIVO_SONECA" 2>/dev/null || echo 0)

    if [ "$UPTIME_DIAS" -ge "$DIAS_LIMITE" ] && [ "$AGORA" -ge "$PROXIMA_PERGUNTA" ]; then
        echo -e "\n⚠️  ATENÇÃO: Sistema ligado há $UPTIME_DIAS dias."
        echo "   Recomendado reiniciar para aplicar kernels/libs."
        echo -n "   Reiniciar agora? (s/N): "
        read -r resposta

        if [[ "$resposta" =~ ^[sS]$ ]]; then
            echo "Reiniciando..."
            sudo reboot
        else
            echo $(( AGORA + HORAS_SONECA * 3600 )) > "$ARQUIVO_SONECA"
            echo "Beleza. Te lembro daqui a $HORAS_SONECA horas."
            sleep 1
            clear
        fi
    fi
}

hq() {
    local pasta="$HOME/Imagens/hqs"

    if [ ! -d "$pasta" ]; then
        echo "Erro: a pasta $pasta não existe."
        return 1
    fi

    local file
    file=$(cd "$pasta" && find . -type f \( -iname "*.pdf" -o -iname "*.cbr" -o -iname "*.cbz" \) \
        | sed "s|^\./||" \
        | fzf --layout=reverse --border --info=inline --prompt="HQ > ")

    if [ -n "$file" ]; then
        flatpak run com.yacreader.YACReader "$pasta/$file" > /dev/null 2>&1 &
    fi
}

y() {
    local tmp
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# bk — sistema de bookmarks (bk, bks, bks verify, unbk, bk --help)
[[ -f ~/.config/bk/bk.sh ]] && source ~/.config/bk/bk.sh

# (tk não é portado aqui — de propósito, ele não usa)

bashrc-help() {
    echo ""
    echo "  ALIASES"
    echo "  :q              sair do terminal (estilo vim)"
    echo "  code            abre VS Code na pasta atual"
    echo "  colheita        roça do semestre: hábitos, provas e boletim no terminal"
    echo ""
    echo "  FUNÇÕES"
    echo "  hq              abre HQ (pdf/cbr/cbz) via fzf + YACReader"
    echo "  y               abre yazi e navega até a pasta escolhida"
    echo "  facul           vai pro semestre mais recente do vault Obsidian"
    echo "  verificar_uptime  avisa se o sistema está ligado há muito tempo"
    echo ""
    echo "  BOOKMARKS  (bk --help para detalhes)"
    bks
}

facul() {
    local base="$HOME/obsidian/5 facul"
    local dest
    dest=$(find "$base" -maxdepth 1 -mindepth 1 -type d | sort -V | tail -1)
    if [ -z "$dest" ]; then
        echo "Nenhum semestre encontrado em: $base"
        return 1
    fi
    cd "$dest" && echo "→ $dest"
}

# ===========================================================
# 4. INICIALIZAÇÃO — starship por último, pra sobrescrever o prompt do OMZ
# ===========================================================

eval "$(starship init zsh)"

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

export PATH=/home/rud/.opencode/bin:$PATH
