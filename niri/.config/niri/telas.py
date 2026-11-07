#!/usr/bin/env python3
"""telas — troca o que está numa tela pelo que está na outra (note ⇄ monitor).

Uso: telas.py  (bind Super+Ctrl+P)

Troca os workspaces ativos das duas saídas, como o swapactiveworkspaces do
Hyprland. Os outros workspaces ficam onde estão. O foco vai junto com o
workspace que estava focado: você continua na janela em que estava.

Fala com o socket do niri direto porque o `niri msg action` só aceita índice
ou nome no --reference, e índice é relativo à tela focada. Aqui é por id.
Com uma tela só (ou três), não faz nada.
"""

from __future__ import annotations

import json
import os
import socket
import sys


def plan(workspaces: list[dict]) -> list[dict] | None:
    """Ações pro niri, ou None se não há exatamente duas telas com workspace ativo."""
    active = [w for w in workspaces if w["is_active"] and w["output"]]
    if len(active) != 2:
        return None
    a, b = active
    focused = next((w for w in active if w["is_focused"]), a)
    return [
        {"MoveWorkspaceToMonitor": {"output": b["output"], "reference": {"Id": a["id"]}}},
        {"MoveWorkspaceToMonitor": {"output": a["output"], "reference": {"Id": b["id"]}}},
        {"FocusWorkspace": {"reference": {"Id": b["id"]}}},
        {"FocusWorkspace": {"reference": {"Id": focused["id"]}}},
    ]


def request(msg: object) -> dict:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect(os.environ["NIRI_SOCKET"])
        s.sendall(json.dumps(msg).encode() + b"\n")
        reply = json.loads(s.makefile().readline())
    if "Err" in reply:
        raise RuntimeError(reply["Err"])
    return reply["Ok"]


def main() -> int:
    workspaces = request("Workspaces")["Workspaces"]
    actions = plan(workspaces)
    if actions is None:
        print("telas: precisa de exatamente duas telas", file=sys.stderr)
        return 1
    for action in actions:
        request({"Action": action})
    return 0


if __name__ == "__main__":
    sys.exit(main())
