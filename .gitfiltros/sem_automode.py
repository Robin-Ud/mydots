#!/usr/bin/env python3
"""Filtro "clean" do git pro claude/.claude/settings.json: tira a chave autoMode.

O Claude Code grava no settings.json um bloco autoMode que descreve a máquina
(cita até os repositórios privados). O mydots é público: no commit o bloco some,
no disco ele fica e continua valendo. Quem liga é o .gitattributes; cada clone
precisa ativar uma vez (o SetNiri.sh faz):

    git config filter.sem-automode.clean 'python3 .gitfiltros/sem_automode.py'

Sem a chave, ou com JSON inválido, o arquivo passa intacto, byte a byte: o
filtro nunca pode comer o arquivo.
"""

import json
import sys


def limpar(bruto: str) -> str:
    try:
        dados = json.loads(bruto)
    except ValueError:
        return bruto
    if not isinstance(dados, dict) or "autoMode" not in dados:
        return bruto
    del dados["autoMode"]
    return json.dumps(dados, indent=2, ensure_ascii=False) + "\n"


if __name__ == "__main__":
    sys.stdout.buffer.write(limpar(sys.stdin.buffer.read().decode("utf-8")).encode("utf-8"))
