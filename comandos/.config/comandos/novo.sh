#!/bin/bash
# Cria um comando novo: "novo nome" e abre no VS Code
# icone: square-plus
nome=$1
[ -z "$nome" ] && { echo "Uso: novo <nome>" >&2; exit 1; }
[[ $nome =~ ^[a-z0-9][a-z0-9_-]*$ ]] || { echo "Nome só com minúsculas, números, - e _" >&2; exit 1; }
dir=$(readlink -f ~/.config/comandos)
arq="$dir/$nome.sh"
if [ ! -e "$arq" ]; then
  cat > "$arq" <<MOLDE
#!/bin/bash
# O que o $nome faz (aparece embaixo do nome no Super+D)
# icone: terminal-2
# modo: notificar
# (modos: notificar = o que imprimir vira notificação; fundo = abre coisa demorada; terminal = interativo)
# (argumentos: "$nome a b" no Super+D → \$1=a \$2=b)

echo "oi do $nome: \$*"
MOLDE
  chmod +x "$arq"
fi
setsid -f code "$dir" "$arq" >/dev/null 2>&1
