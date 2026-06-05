#!/bin/bash
# att_diaria.sh — Atualização diária do sistema
# Chamado pelo Hyprland no boot (exec-once = kitty -e att_diaria.sh).
# Abre no kitty, roda um cmatrix de boas-vindas e atualiza via dnf.
# Se já atualizou hoje, fecha a janela imediatamente sem fazer nada.

clear
sleep 0.5

# Animação de abertura — pressione qualquer tecla para pular
cmatrix -ba -s

clear

# Verifica se já atualizou hoje (evita atualizar duas vezes no mesmo dia)
ARQUIVO_CONTROLE="$HOME/.cache/last_upd"
if [ "$(cat "$ARQUIVO_CONTROLE" 2>/dev/null)" == "$(date +%F)" ]; then
    kill -9 $PPID   # Fecha a janela do kitty
    exit 0
fi

echo "🔍 Buscando atualizações..."

if sudo dnf update -y --refresh; then
    date +%F > "$ARQUIVO_CONTROLE"
    echo ""
    echo "✅ Sistema atualizado!"
    echo "👋 Fechando..."
    sleep 2
    clear
    kill -9 $PPID
else
    echo ""
    echo "❌ Erro na atualização."
    read -p "Enter para fechar..."
    kill -9 $PPID
fi
