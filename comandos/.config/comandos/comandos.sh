#!/bin/bash
# Abre a pasta dos comandos no VS Code
# icone: folder-code
# modo: fundo
exec setsid -f code "$(readlink -f ~/.config/comandos)"
