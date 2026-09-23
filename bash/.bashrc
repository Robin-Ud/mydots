# .bashrc — Configuração do shell interativo (Bash)
# Carregado toda vez que você abre um terminal novo.
#
# Voltou a ser o shell principal em 13/08/2026 (migração de volta do zsh).
# O que o zsh dava e não vinha de graça aqui está resolvido assim:
#   - autosuggestion + syntax highlighting  → ble.sh (seção 0)
#   - hook `preexec` do UsageTracker        → seção 3.5, via PROMPT_COMMAND

# ===========================================================
# 0. BLE.SH — line editor: autosuggestion cinza + syntax highlighting
#     Instalado em ~/.local/share/blesh (build da fonte, `make install`).
#     A ORDEM É OBRIGATÓRIA: source com --noattach aqui no topo, e o
#     `ble-attach` na ÚLTIMA linha do arquivo. Sem isso ele briga com o
#     fzf e com o starship.
#     PRA DESLIGAR: comente esta linha e a do `ble-attach` lá embaixo. O
#     bash cai no readline puro, e o ↑/↓ da seção 1 continua valendo.
# ===========================================================

[[ $- == *i* ]] && [[ -f ~/.local/share/blesh/ble.sh ]] &&
    source ~/.local/share/blesh/ble.sh --noattach

# ===========================================================
# 1. SISTEMA — configurações globais, PATH e histórico
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

# --- histórico ---------------------------------------------------------
# O padrão do Fedora é 1000/500, o que é pouco e faz o bash truncar o
# arquivo direto. Cada truncamento escreve um .bash_history-$$.tmp e, se o
# terminal morrer no meio (fechar janela no Hyprland), o .tmp fica órfão —
# foi assim que 11 deles se acumularam na home. Arquivo grande + `history -a`
# a cada prompt (seção 3.5) resolvem a causa.
HISTSIZE=100000
HISTFILESIZE=200000
HISTTIMEFORMAT='%F %T '
shopt -s histappend

# ignorespace (e não ignoreboth) de propósito: comandos repetidos CONTINUAM
# entrando no histórico, o que mantém honesta a contagem do UsageTracker.
# O que ele ignora é comando começando com espaço — o seu escape de
# "não registra esse".
HISTCONTROL=ignorespace

# --- readline ----------------------------------------------------------
# ↑/↓ buscam no histórico pelo prefixo já digitado, em vez de só rolar a
# lista. É a rede de segurança do autosuggestion: continua valendo se o
# ble.sh sair de cena.
bind '"\e[A": history-search-backward' 2>/dev/null
bind '"\e[B": history-search-forward'  2>/dev/null

# --- fzf ---------------------------------------------------------------
export FZF_DEFAULT_OPTS="--preview 'bat --color=always {}'"

# key-bindings do fzf (Ctrl+R histórico, Ctrl+O arquivos, Alt+C diretórios).
# Sob ble.sh usamos a integração dele, que é a versão que não briga com o
# line editor; sem ble.sh, o script do sistema.
if [[ ${BLE_VERSION-} ]]; then
    ble-import -d integration/fzf-completion
    ble-import -d integration/fzf-key-bindings

    # Ctrl+O em vez de Ctrl+T pro buscador de arquivos, igual ao quick
    # switcher do Obsidian. accept-and-next é o default do keymap emacs
    # do ble.sh pra Ctrl+T (ver lib/keymap.emacs.sh), então restauramos
    # isso ao desfazer o bind que a integração acima criou.
    ble-bind -f C-t accept-and-next
    ble-bind -m emacs   -x C-o fzf-file-widget
    ble-bind -m vi_imap -x C-o fzf-file-widget
    ble-bind -m vi_nmap -s C-o 'i\C-o'
else
    source /usr/share/fzf/shell/key-bindings.bash

    # Ctrl+O em vez de Ctrl+T pro buscador de arquivos, igual ao quick
    # switcher do Obsidian. transpose-chars é o default do readline pra
    # Ctrl+T, então restauramos isso ao desfazer o bind que o script
    # acima criou.
    bind -m emacs-standard '"\C-t": transpose-chars'
    bind -m vi-command '"\C-t": "\C-t"'
    bind -m vi-insert '"\C-t": "\C-t"'
    bind -m emacs-standard -x '"\C-o": fzf-file-widget'
    bind -m vi-command -x '"\C-o": fzf-file-widget'
    bind -m vi-insert -x '"\C-o": fzf-file-widget'
fi

# ===========================================================
# 2. ALIASES — atalhos de comandos
# ===========================================================

alias pt='pytest -xv test.py'                    # roda o teste do projeto atual
alias :q='exit'                                  # Sair como no vim
alias ..='cd ..'                                 # sobe um diretório
alias code='code .'                              # Abre o VS Code na pasta atual
alias colheita='~/deving/colheita/colheita.sh'   # Fazenda viva: seus hábitos no terminal

# ===========================================================
# 3. FUNÇÕES
# ===========================================================

# rm — vai para a lixeira em vez de destruir. Desfaz com `trash-restore`.
# As flags do rm (-r, -f, -rf, -i) sao ACEITAS E IGNORADAS de proposito: o
# hábito de digitar `rm -rf` nao pode furar a rede de protecao.
# Para destruir de verdade: `rmf` (abaixo) ou `command rm -rf`.
# Atencao: nada disso vale em `sudo rm`, em script, nem em outra maquina.
rm() {
    local alvos=()
    local a
    for a in "$@"; do
        case "$a" in
            --) ;;
            -*) ;;                       # absorve flag do rm
            *) alvos+=("$a") ;;
        esac
    done
    if [[ ${#alvos[@]} -eq 0 ]]; then
        echo "rm: nada a apagar" >&2
        return 1
    fi
    if ! command -v trash-put >/dev/null; then
        # Sem trash-put NAO cai para o rm real: o default aqui nunca destroi.
        echo "rm: trash-cli nao instalado (sudo dnf install trash-cli)." >&2
        echo "    para apagar definitivamente: rmf ${alvos[*]}" >&2
        return 1
    fi
    trash-put -- "${alvos[@]}"
}

# rmf — destruicao real, sem lixeira. O gesto perigoso agora tem nome proprio.
rmf() {
    command rm -rf "$@"
}

# setluz — brilho da tela (setluz 40) ou do teclado (setluz -k 2)
setluz() {
    if [[ "$1" == "-k" ]]; then
        local dev
        dev=$(ls -d /sys/class/leds/*kbd_backlight 2>/dev/null | head -1)
        if [[ -z "$dev" ]]; then
            echo "setluz: este teclado não tem backlight (nenhum *kbd_backlight em /sys/class/leds)" >&2
            return 1
        fi
        brightnessctl --device="${dev##*/}" set "$2"
    else
        brightnessctl set "${1}%"
    fi
}

# setled — ThinkLight + LEDs de status (power, logo da tampa, standby, ThinkVantage)
setled() {
    local alvo="$1"
    local valor="$2"
    local dev

    case "$alvo" in
        thinklight) dev='tpacpi::thinklight' ;;
        power)      dev='tpacpi::power' ;;
        logo)       dev='tpacpi::lid_logo_dot' ;;
        standby)    dev='tpacpi::standby' ;;
        tv)         dev='tpacpi::thinkvantage' ;;
        all)
            for dev in tpacpi::thinklight tpacpi::power tpacpi::lid_logo_dot tpacpi::standby tpacpi::thinkvantage; do
                brightnessctl --device="$dev" set "$valor" &>/dev/null
            done
            return
            ;;
        *)
            echo "uso: setled <thinklight|power|logo|standby|tv|all> <valor>" >&2
            return 1
            ;;
    esac

    brightnessctl --device="$dev" set "$valor"
}

# settela — espelhar/isolar monitor externo (settela espelhar | so-externo | normal)
settela() {
    local ext
    ext=$(hyprctl monitors -j | jq -r '.[] | select(.name != "eDP-1") | .name' | head -1)

    case "$1" in
        espelhar)
            if [[ -z "$ext" ]]; then
                echo "settela: nenhum monitor externo conectado" >&2
                return 1
            fi
            hyprctl keyword monitor "$ext,preferred,auto,1,mirror,eDP-1"
            ;;
        so-externo)
            if [[ -z "$ext" ]]; then
                echo "settela: nenhum monitor externo conectado" >&2
                return 1
            fi
            hyprctl keyword monitor "eDP-1,disable"
            ;;
        normal)
            hyprctl keyword monitor "eDP-1,preferred,auto,1"
            [[ -n "$ext" ]] && hyprctl keyword monitor "$ext,preferred,auto,1"
            ;;
        *)
            echo "uso: settela espelhar | so-externo | normal" >&2
            return 1
            ;;
    esac
}

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

# bk — sistema de bookmarks (bk, bks, bks verify, unbk, bk --help)
[[ -f ~/.config/bk/bk.sh ]] && source ~/.config/bk/bk.sh

# bashrc-help — mostra todas as funções e aliases customizados
bashrc-help() {
    echo ""
    echo "  ALIASES"
    echo "  pt              pytest -xv test.py"
    echo "  :q              sair do terminal (estilo vim)"
    echo "  ..              sobe um diretório"
    echo "  code            abre VS Code na pasta atual"
    echo "  colheita        roça do semestre: hábitos, provas e boletim no terminal"
    echo ""
    echo "  FUNÇÕES"
    echo "  hq              abre HQ (pdf/cbr/cbz) via fzf + YACReader"
    echo "  y               abre yazi e navega até a pasta escolhida"
    echo "  facul           vai pro semestre mais recente do vault Obsidian"
    echo "  setluz          brilho da tela (setluz 40) ou do teclado (setluz -k 2)"
    echo "  setled          LEDs do ThinkPad (setled thinklight 1 | setled all 0)"
    echo "  settela         espelhar/isolar monitor externo (settela espelhar | so-externo | normal)"
    echo "  hyprwiki        abre a wiki do Hyprland offline"
    echo "  verificar_uptime  avisa se o sistema está ligado há muito tempo"
    echo ""
    echo "  BOOKMARKS  (bk --help para detalhes)"
    bks
}

# ===========================================================
# 3.5 USAGE TRACKING — loga o primeiro token de cada comando digitado
#     (ver ~/deving/UsageTracker; relatório: `usage-report`)
#
#     No zsh isso era um `add-zsh-hook preexec`. Bash não tem preexec: o
#     trap DEBUG dispara uma vez por comando de pipeline (`ls | grep x`
#     contaria 2) e já é território do starship. Então lemos a última
#     entrada do histórico a cada prompt — dispara exatamente uma vez por
#     linha digitada, e funciona com ou sem ble.sh.
#
#     Diferença única vs. zsh: o timestamp é o do FIM do comando, não o do
#     início. Irrelevante pro usage_tracker.py, que só usa o ts pra "última
#     vez usado em DD/MM" e detecção de stale.
# ===========================================================

_usage_tracker_last=
_usage_tracker_log() {
    local dir="$HOME/.local/share/usage-tracker"
    local hist n cmd

    # `read` com IFS padrão resolve os dois detalhes chatos da saída do
    # `history`: a indentação da esquerda e os DOIS espaços entre o número e
    # o comando. Fatiar isso na mão com ${x#* } deixa um espaço sobrando e
    # ${cmd%% *} devolve string vazia — foi exatamente esse o bug.
    read -r n cmd <<< "$(HISTTIMEFORMAT= history 1)"

    # nada novo: Enter vazio, ou comando com espaço na frente (ignorespace)
    [[ -z $cmd || $n == "$_usage_tracker_last" ]] && return
    _usage_tracker_last=$n

    [[ -d $dir ]] || mkdir -p "$dir"
    printf '%s\t%s\n' "$EPOCHSECONDS" "${cmd%% *}" >> "$dir/cmd_log.tsv"
}

_bashrc_prompt_hook() {
    _usage_tracker_log
    history -a   # grava já: terminal morto não leva o histórico junto
}

# O /etc/bashrc do Fedora declara PROMPT_COMMAND como array (declare -a),
# mas em outros contextos ele vem como string simples. Registra do jeito certo
# pros dois casos.
if [[ ${PROMPT_COMMAND@a} == *a* ]]; then
    PROMPT_COMMAND+=(_bashrc_prompt_hook)
else
    PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}_bashrc_prompt_hook"
fi

# ===========================================================
# 4. INICIALIZAÇÃO — roda ao abrir cada terminal
# ===========================================================

# Prompt bonito com informações de git, tempo de comando, etc.
# Precisa vir DEPOIS do source do ble.sh: o `starship init bash` detecta
# $BLE_VERSION e se pluga via blehook em vez de mexer no PROMPT_COMMAND.
eval "$(starship init bash)"

# Ferramentas instaladas via Rust/Cargo
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# opencode
export PATH=/home/rud/.opencode/bin:$PATH

# ble.sh: attach por último, com tudo já configurado (ver seção 0).
[[ ${BLE_VERSION-} ]] && ble-attach
