#!/usr/bin/env python3
"""tablet — troca a tela da mesa digitalizadora (Alt+W): notebook → externo → os dois.

Uso: tablet.py [eDP-1|HDMI-A-1|ambos]   (sem argumento, vai pra próxima)

Escreve tablet.kdl do lado do config.kdl (fora do git); o niri vigia o include
e aplica na hora. O padrão de cada máquina continua no local.kdl; o tablet.kdl
vale por cima dele, e uma seção tablet vazia mapeia nos dois monitores (no niri
seção de dispositivo apontador incluída depois substitui, não mescla).
"""

from __future__ import annotations

import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.realpath(__file__))
FILE = os.path.join(HERE, "tablet.kdl")
CYCLE = ["eDP-1", "HDMI-A-1", "ambos"]
LABEL = {"eDP-1": "Notebook (eDP-1)", "HDMI-A-1": "LG UltraGear (HDMI-A-1)",
         "ambos": "Ambos os monitores"}


def current(text: str | None) -> str:
    """Tela atual pelo conteúdo do tablet.kdl; sem arquivo = padrão do local.kdl."""
    if text is None:
        return "eDP-1"
    m = re.search(r'map-to-output\s+"([^"]+)"', text)
    return m.group(1) if m else "ambos"


def following(now: str) -> str:
    return CYCLE[(CYCLE.index(now) + 1) % len(CYCLE)] if now in CYCLE else CYCLE[0]


def render(target: str) -> str:
    inner = "" if target == "ambos" else f'\n        map-to-output "{target}"'
    return ("// Gerado pelo tablet.py (Alt+W) — não editar, não vai pro git.\n"
            f"input {{\n    tablet {{{inner}\n    }}\n}}\n")


def main() -> int:
    if len(sys.argv) > 2 or (len(sys.argv) == 2 and sys.argv[1] not in CYCLE):
        print(__doc__, file=sys.stderr)
        return 2
    try:
        with open(FILE) as f:
            text = f.read()
    except FileNotFoundError:
        text = None
    target = sys.argv[1] if len(sys.argv) == 2 else following(current(text))
    with open(FILE, "w") as f:
        f.write(render(target))
    subprocess.run(["notify-send", "-t", "2000", "Mesa Digitalizadora",
                    f"Mapeada para {LABEL[target]}"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
