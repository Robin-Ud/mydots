#!/usr/bin/env python3
"""cycle — passa por todas as janelas do workspace, coluna por coluna.

Uso: cycle.py next|prev  (binds Alt+Tab / Alt+Shift+Tab)

O cyclenext do Hyprland: desce pela pilha da coluna, vai pra próxima coluna e,
no fim, volta pra primeira. O focus-column-* do niri pula a pilha inteira.
Janela flutuante fica de fora (não tem posição na coluna).
"""

from __future__ import annotations

import json
import subprocess
import sys


def next_window(windows: list[dict], focused: dict | None, step: int) -> dict | None:
    """A janela `step` posições depois da focada, na ordem (coluna, linha)."""
    if focused is None:
        return None
    tiled = sorted(
        (w for w in windows
         if w["workspace_id"] == focused["workspace_id"]
         and w["layout"].get("pos_in_scrolling_layout")),
        key=lambda w: w["layout"]["pos_in_scrolling_layout"],
    )
    if not tiled:
        return None
    ids = [w["id"] for w in tiled]
    if focused["id"] not in ids:
        return tiled[0]  # focada é flutuante: começa pela primeira
    return tiled[(ids.index(focused["id"]) + step) % len(tiled)]


def niri(*args: str) -> str:
    return subprocess.run(["niri", "msg", *args], capture_output=True, text=True).stdout


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in ("next", "prev"):
        print(__doc__, file=sys.stderr)
        return 2
    step = 1 if sys.argv[1] == "next" else -1
    try:
        focused = json.loads(niri("-j", "focused-window"))
        windows = json.loads(niri("-j", "windows"))
        target = next_window(windows, focused, step)
    except (json.JSONDecodeError, KeyError, TypeError):
        return 1
    if target is None:
        return 0
    niri("action", "focus-window", "--id", str(target["id"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
