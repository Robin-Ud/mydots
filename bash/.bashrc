# .bashrc

# ===========================================================
# 1. DEFINIÇÕES GLOBAIS E DE SISTEMA
# ===========================================================
# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
  PATH="$HOME/.local/bin:$HOME/bin:$PATH"
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
# Atualiza e cria o arquivo de controle para os scripts não rodarem de novo hoje
alias up='sudo dnf update -y --refresh && echo $(date +%F) > ~/.last_upd && echo "✅ Scripts sincronizados!"'

# ===========================================================
# 3. FUNÇÕES
# ===========================================================
verificar_uptime() {
    # Configuração
    local DIAS_LIMITE=1            # Avisar se ligado há mais de X dias
    local HORAS_SONECA=2           # Se negar, perguntar de novo em X horas
    local ARQUIVO_SONECA="$HOME/.soneca_reboot_time"

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

# ===========================================================
# 4. EXECUÇÃO AO INICIAR (Interactive Shell Only)
# ===========================================================

# starship
eval "$(starship init bash)"

# Executa apenas se for um terminal interativo
if [[ $- == *i* ]]; then
    # 1. Verifica se precisa reiniciar
    verificar_uptime

    # 2. Mostra o Pokemon (sempre roda, mesmo após o clear da soneca)
    if command -v pokemon-colorscripts &> /dev/null; then
        pokemon-colorscripts --random
    fi
fi
