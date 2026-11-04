#!/usr/bin/env python3
"""scratch — scratchpad igual ao special:magic do Hyprland.

Uso: scratch.py send|toggle  (binds Super+Shift+s / Super+s)

O niri não tem workspace escondido: o scratchpad é um workspace comum no fim da
lista, lembrado pelo id. toggle entra nele (o que abrir ali nasce no scratchpad,
e o solo.py deixa a janela sozinha em 100%) e, de dentro dele, volta pra onde
você estava. send manda a janela focada pra lá; de dentro do scratchpad, manda
ela de volta. Workspace com nome não serve: o niri põe ele no índice 1.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys

STATE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "niri-scratch.json")


def by_id(workspaces: list[dict], ws_id: int | None) -> dict | None:
    return next((w for w in workspaces if w["id"] == ws_id), None)


def end_idx(workspaces: list[dict], output: str) -> int:
    """Índice do workspace vazio que o niri sempre deixa no fim do monitor."""
    return max(w["idx"] for w in workspaces if w["output"] == output)


def toggle_plan(state: dict, workspaces: list[dict], current: dict) -> tuple[str, int]:
    """("back", idx) sai do scratchpad; ("go", idx) entra; ("new", idx) cria no fim."""
    scratch = by_id(workspaces, state.get("ws"))
    if scratch and scratch["id"] == current["id"]:
        back = by_id(workspaces, state.get("back"))
        return "back", back["idx"] if back else 1
    if scratch and scratch["output"] == current["output"]:
        return "go", scratch["idx"]
    return "new", end_idx(workspaces, current["output"])


def niri(*args: str) -> str:
    return subprocess.run(["niri", "msg", *args], capture_output=True, text=True).stdout


def focused_ws() -> dict:
    return next(w for w in json.loads(niri("-j", "workspaces")) if w["is_focused"])


def load() -> dict:
    try:
        with open(STATE) as f:
            state = json.load(f)
        return state if isinstance(state, dict) else {}
    except (OSError, ValueError):
        return {}


def save(state: dict) -> None:
    with open(STATE, "w") as f:
        json.dump(state, f)


def toggle(state: dict, workspaces: list[dict], current: dict) -> None:
    action, idx = toggle_plan(state, workspaces, current)
    if action != "back":
        state["back"] = current["id"]
    niri("action", "focus-workspace", str(idx))
    if action == "new":
        state["ws"] = focused_ws()["id"]


def send(state: dict, workspaces: list[dict], current: dict) -> None:
    window = json.loads(niri("-j", "focused-window") or "null")
    if not window:
        return
    scratch = by_id(workspaces, state.get("ws"))
    if scratch and scratch["id"] == current["id"]:
        back = by_id(workspaces, state.get("back"))
        target = back["idx"] if back else 1
    elif scratch and scratch["output"] == current["output"]:
        target = scratch["idx"]
    else:
        target = end_idx(workspaces, current["output"])
        scratch = None
    niri("action", "move-window-to-workspace", "--focus", "false", str(target))
    if scratch is None:
        moved = next(w for w in json.loads(niri("-j", "windows")) if w["id"] == window["id"])
        state["ws"] = moved["workspace_id"]


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in ("send", "toggle"):
        print(__doc__, file=sys.stderr)
        return 2
    try:
        workspaces = json.loads(niri("-j", "workspaces"))
        current = next(w for w in workspaces if w["is_focused"])
    except (json.JSONDecodeError, StopIteration):
        return 1
    state = load()
    (send if sys.argv[1] == "send" else toggle)(state, workspaces, current)
    save(state)
    return 0


if __name__ == "__main__":
    sys.exit(main())
