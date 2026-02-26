# .bashrc

# ===========================================================
# 1. DEFINIÇÕES GLOBAIS E DE SISTEMA
# ===========================================================
# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

# --- XDG & LIMPEZA DA HOME ---
# Força o NPM a usar pastas ocultas corretas em vez de sujar a raiz
export NPM_CONFIG_USERCONFIG="$HOME/.config/npm/npmrc"
export NPM_CONFIG_CACHE="$HOME/.cache/npm"
export EDITOR=nvim

# User specific environment
# Adiciona apenas .local/bin (já que você moveu o bin antigo pra lá)
if ! [[ "$PATH" =~ "$HOME/.local/bin:" ]]; then
  PATH="$HOME/.local/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# Carrega configurações modulares (se existirem)
if [ -d ~/.bashrc.d ]; then
  for rc in ~/.bashrc.d/*; do
    if [ -f "$rc" ]; then
      . "$rc"
    fi
  done
fi
unset rc

# ===========================================================
# 2. ALIASES
# ===========================================================
# Sistema
# Atualiza e salva o log no CACHE para não sujar a home
alias up='sudo dnf update -y --refresh && echo $(date +%F) > ~/.cache/last_upd && echo "✅ Scripts sincronizados!"'
alias :q='exit'
# ===========================================================
# 3. FUNÇÕES
# ===========================================================
verificar_uptime() {
    # Configuração
    local DIAS_LIMITE=1            # Avisar se ligado há mais de X dias
    local HORAS_SONECA=2           # Se negar, perguntar de novo em X horas
    # MUDANÇA: Salva o arquivo de controle no cache, não na home
    local ARQUIVO_SONECA="$HOME/.cache/soneca_reboot_time"

    # 1. Checa Uptime (dias)
    local UPTIME_SEG=$(cat /proc/uptime | cut -d. -f1)
    local UPTIME_DIAS=$((UPTIME_SEG / 86400))

    # 2. Checa Soneca (timestamp)
    local AGORA=$(date +%s)
    local PROXIMA_PERGUNTA=$(cat "$ARQUIVO_SONECA" 2>/dev/null || echo 0)

    # Lógica
    if [ "$UPTIME_DIAS" -ge "$DIAS_LIMITE" ] && [ "$AGORA" -ge "$PROXIMA_PERGUNTA" ]; then
        
        echo -e "\n⚠️  ATENÇÃO: Sistema ligado há $UPTIME_DIAS dias."
        echo "   Recomendado reiniciar para aplicar kernels/libs."
        echo -n "   Reiniciar agora? (s/N): "
        read -r resposta

        if [[ "$resposta" =~ ^[sS]$ ]]; then
            echo "Reiniciando..."
            sudo reboot
        else
            # Calcula nova soneca: Agora + (Horas * 3600)
            local NOVA_HORA=$((AGORA + HORAS_SONECA * 3600))
            echo "$NOVA_HORA" > "$ARQUIVO_SONECA"
            
            echo "Beleza. Te lembro daqui a $HORAS_SONECA horas."
            sleep 1
            
            # Limpa o aviso para deixar o terminal pronto para o Pokemon
            clear 
        fi
    fi
}
hq() {
    # Pasta das HQs
    local pasta="$HOME/Imagens/hqs"

    # Verifica se a pasta existe antes de tentar
    if [ ! -d "$pasta" ]; then
        echo "Erro: A pasta $pasta não existe!"
        return 1
    fi

    # Busca PDF, CBR e CBZ (case insensitive)
    # Usa subshell () para o 'cd' não mudar você de pasta no terminal
    local file
    file=$(cd "$pasta" && find . -type f \( -iname "*.pdf" -o -iname "*.cbr" -o -iname "*.cbz" \) | sed "s|^\./||" | fzf --layout=reverse --border --info=inline --prompt="HQ > ")
    
    # Se escolheu algo, abre com o YACReader (caminho completo para não dar erro)
    if [ -n "$file" ]; then
        flatpak run com.yacreader.YACReader "$pasta/$file" > /dev/null 2>&1 &
    fi
}
# ===========================================================
# 4. EXECUÇÃO AO INICIAR (Interactive Shell Only)
# ===========================================================

# starship
eval "$(starship init bash)"


. "$HOME/.cargo/env"
