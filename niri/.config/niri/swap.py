#!/usr/bin/env python3
"""swap — troca a janela com a coluna do lado e troca as larguras também.

Uso: swap.py left|right  (binds Super+Ctrl+h/l)

O swap-window do niri leva a largura junto com a janela; aqui a largura fica
com o lado, como no master do Hyprland: quem vai pro lado grande fica grande.
"""

from __future__ import annotations

import json
import subprocess
import sys

GAPS = 2    # igual ao `gaps` do config.kdl
STRUTS = 8  # struts left + right do config.kdl


def proportion(tile_width: float, view_width: float, gaps: int = GAPS, struts: int = STRUTS) -> str:
    """Largura em % do jeito que o niri calcula: (view - struts - gaps) * p - gaps."""
    return f"{(tile_width + gaps) / (view_width - struts - gaps) * 100:.2f}%"


def neighbor(windows: list[dict], focused: dict, direction: str) -> dict | None:
    """Uma janela da coluna vizinha no mesmo workspace (a largura é da coluna)."""
    col = focused["layout"]["pos_in_scrolling_layout"][0]
    target = col - 1 if direction == "left" else col + 1
    for w in windows:
        pos = w["layout"].get("pos_in_scrolling_layout")
        if w["workspace_id"] == focused["workspace_id"] and pos and pos[0] == target:
            return w
    return None


def niri(*args: str) -> str:
    return subprocess.run(["niri", "msg", *args], capture_output=True, text=True).stdout


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in ("left", "right"):
        print(__doc__, file=sys.stderr)
        return 2
    direction = sys.argv[1]
    try:
        focused = json.loads(niri("-j", "focused-window"))
        windows = json.loads(niri("-j", "windows"))
        view = json.loads(niri("-j", "focused-output"))["logical"]["width"]
        other = neighbor(windows, focused, direction)
    except (json.JSONDecodeError, KeyError, TypeError, IndexError):
        return 1  # nada focado ou janela flutuante
    if other is None:
        return 0

    mine = proportion(focused["layout"]["tile_size"][0], view)
    theirs = proportion(other["layout"]["tile_size"][0], view)
    niri("action", f"swap-window-{direction}")
    niri("action", "set-window-width", "--id", str(focused["id"]), theirs)
    niri("action", "set-window-width", "--id", str(other["id"]), mine)
    return 0


if __name__ == "__main__":
    sys.exit(main())
