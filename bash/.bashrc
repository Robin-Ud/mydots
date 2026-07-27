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

# seta uma config padrão pra fzf
export FZF_DEFAULT_OPTS="--preview 'bat --color=always {}'"

# key-bindings do fzf (Ctrl+R histórico, Ctrl+T arquivos, Alt+C diretórios)
source /usr/share/fzf/shell/key-bindings.bash
# ===========================================================
# 2. ALIASES — atalhos de comandos
# ===========================================================

alias :q='exit'        # Sair como no vim
alias code='code .'    # Abre o VS Code na pasta atual
alias colheita='~/deving/colheita/colheita.sh'   # Fazenda viva: seus hábitos no terminal

# ===========================================================
# 3. FUNÇÕES
# ===========================================================

# hyprwiki — abre a wiki do Hyprland offline (espelho em ~/hyprland-wiki-0.51.0)
hyprwiki() {
    local porta=8631
    if ! curl -s -o /dev/null "http://localhost:$porta/0.51.0/"; then
        (cd ~/hyprland-wiki-0.51.0 && python3 -m http.server "$porta" &>/dev/null &)
        sleep 0.5
    fi
    xdg-open "http://localhost:$porta/0.51.0/"
}

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

# bk — sistema de bookmarks (bk, bks, bks verify, unbk, bk --help)
[[ -f ~/.config/bk/bk.sh ]] && source ~/.config/bk/bk.sh

# tk — notas/aprovação das provas (tk, tks, tk passei, tk -h)
[[ -f ~/deving/colheita/tk.sh ]] && source ~/deving/colheita/tk.sh

# bashrc-help — mostra todas as funções e aliases customizados
bashrc-help() {
    echo ""
    echo "  ALIASES"
    echo "  :q              sair do terminal (estilo vim)"
    echo "  code            abre VS Code na pasta atual"
    echo "  colheita        roça do semestre: hábitos, provas e boletim no terminal"
    echo "  tk / tks        lançar notas das provas e ver se passou (tk -h)"
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

# opencode
export PATH=/home/rud/.opencode/bin:$PATH
