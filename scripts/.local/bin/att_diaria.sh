#!/bin/bash

# 1. PREPARAÇÃO (Limpa tudo antes de começar)
clear
sleep 0.5

# 2. MATRIX
# Roda o Matrix e espera você teclar algo
cmatrix -ba -s 

# Assim que sair do Matrix:
clear

# 3. VERIFICAÇÃO RAPIDA
# Se já atualizou hoje, mata a janela imediatamente
if [ "$(cat ~/.last_upd 2>/dev/null)" == "$(date +%F)" ]; then
    kill -9 $PPID
fi

# 4. ATUALIZAÇÃO
echo "🔍 Buscando atualizações..."

# Tenta atualizar
if sudo dnf update -y --refresh; then
    # --- SUCESSO ---
    echo $(date +%F) > ~/.last_upd
    echo ""
    echo "✅ Atualizado!"
    echo "👋 Fechando..."
    sleep 2
    
    # --- A MÁGICA DO CLEAR ---
    clear 
    
    # --- O ASSASSINO ---
    # Mata o processo pai (o terminal Kitty/Alacritty) forçadamente.
    # Isso garante que a janela feche, não importa a configuração.
    kill -9 $PPID
else
    # --- ERRO ---
    echo ""
    echo "❌ Erro na atualização."
    read -p "Enter para fechar..."
    kill -9 $PPID
fi
