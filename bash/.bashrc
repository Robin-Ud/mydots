# .bashrc — Configuração do shell interativo (Bash)
# Carregado toda vez que você abre um terminal novo.

# ===========================================================
# 1. SISTEMA — configurações globais e PATH
# ===========================================================

# Carrega as definições globais do sistema (Fedora)
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Garante que ~/.local/bin esteja no PATH (onde ficam seus scripts)
if ! [[ "$PATH" =~ "$HOME/.local/bin:" ]]; then
    PATH="$HOME/.local/bin:$PATH"
fi
export PATH

# Editor padrão para o terminal (git commit, etc.)
export EDITOR=nvim

# NPM: usa pastas corretas em vez de criar lixo na home
export NPM_CONFIG_USERCONFIG="$HOME/.config/npm/npmrc"
export NPM_CONFIG_CACHE="$HOME/.cache/npm"

# Carrega configs modulares da pasta ~/.bashrc.d/ (se existirem)
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        [ -f "$rc" ] && . "$rc"
    done
    unset rc
fi

# ===========================================================
# 2. ALIASES — atalhos de comandos
# ===========================================================

alias :q='exit'        # Sair como no vim
alias code='code .'    # Abre o VS Code na pasta atual

# ===========================================================
# 3. FUNÇÕES
# ===========================================================

# verificar_uptime — avisa quando o sistema está ligado há muito tempo
# Útil para lembrar de reiniciar e aplicar atualizações de kernel.
verificar_uptime() {
    local DIAS_LIMITE=1                                    # Avisa se ligado há mais de X dias
    local HORAS_SONECA=2                                   # Pergunta de novo em X horas se você negar
    local ARQUIVO_SONECA="$HOME/.cache/soneca_reboot_time" # Controla o intervalo entre perguntas

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

# hq — abre HQs (PDF, CBR, CBZ) com o YACReader via fzf
# Busca em ~/Imagens/hqs/ e abre a selecionada
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

# y — abre o yazi (gerenciador de arquivos no terminal) e navega até a pasta escolhida
# Ao sair do yazi, o terminal já está na pasta que você estava navegando
y() {
    local tmp
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# bk — salva alias de cd para o diretório atual
bk() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "Uso: bk <nome>"
        return 1
    fi
    local path
    path="$(pwd)"
    local entry="alias ${name}='cd \"${path}\"'  # bookmark"
    if grep -q "^alias ${name}=.*# bookmark" ~/.bashrc; then
        sed -i "s|^alias ${name}=.*# bookmark|${entry}|" ~/.bashrc
        echo "Atualizado: ${name} → ${path}"
    else
        echo "${entry}" >> ~/.bashrc
        echo "Salvo: ${name} → ${path}"
    fi
    eval "alias ${name}='cd \"${path}\"'"
}

# bks — lista todos os bookmarks salvos
bks() {
    grep "# bookmark$" ~/.bashrc | sed "s/alias //;s/='cd.*# bookmark//" \
        | while IFS= read -r name; do
            local dest
            dest=$(grep "^alias ${name}=.*# bookmark" ~/.bashrc \
                | sed "s/.*='cd \"//;s/\"'.*//")
            printf "  %-20s %s\n" "$name" "$dest"
          done
}

# unbk — remove um bookmark pelo nome
unbk() {
    local name="$1"
    if [ -z "$name" ]; then
        echo "Uso: unbk <nome>"
        return 1
    fi
    if grep -q "^alias ${name}=.*# bookmark" ~/.bashrc; then
        sed -i "/^alias ${name}=.*# bookmark/d" ~/.bashrc
        unalias "$name" 2>/dev/null
        echo "Removido: ${name}"
    else
        echo "Bookmark não encontrado: ${name}"
        return 1
    fi
}

# bashrc-help — mostra todas as funções e aliases customizados
bashrc-help() {
    echo ""
    echo "  ALIASES"
    echo "  :q              sair do terminal (estilo vim)"
    echo "  code            abre VS Code na pasta atual"
    echo ""
    echo "  FUNÇÕES"
    echo "  hq              abre HQ (pdf/cbr/cbz) via fzf + YACReader"
    echo "  y               abre yazi e navega até a pasta escolhida"
    echo "  facul           vai pro semestre mais recente do vault Obsidian"
    echo "  verificar_uptime  avisa se o sistema está ligado há muito tempo"
    echo ""
    echo "  BOOKMARKS"
    echo "  bk <nome>       salva alias para a pasta atual"
    echo "  bks             lista todos os bookmarks"
    echo "  unbk <nome>     remove um bookmark"
    echo ""
    if grep -q "# bookmark$" ~/.bashrc; then
        echo "  bookmarks ativos:"
        bks
        echo ""
    fi
}

# facul — vai pro semestre mais recente do vault Obsidian
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
# 4. INICIALIZAÇÃO — roda ao abrir cada terminal
# ===========================================================

# Prompt bonito com informações de git, tempo de comando, etc.
eval "$(starship init bash)"

# Ferramentas instaladas via Rust/Cargo
. "$HOME/.cargo/env"

# Atuin: histórico de comandos melhorado (com busca e sync)
. "$HOME/.atuin/bin/env"
[[ -f ~/.bash-preexec.sh ]] && source ~/.bash-preexec.sh
eval "$(atuin init bash)"
alias prova='cd "/home/rud/obsidian/5 facul/5 semestre/5.1 fisica do ambiente/p3"'  # bookmark
