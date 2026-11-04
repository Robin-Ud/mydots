#!/usr/bin/env python3
"""solo — janela sozinha no workspace ocupa a tela toda; chegou a segunda, volta a 50/50.

O niri não tem regra de "única janela", então isto escuta o event-stream e
ajusta a largura pela IPC. Só mexe em coluna que ele mesmo alargou: se você
mudar a largura na mão, ele não briga.
"""

from __future__ import annotations

import json
import subprocess
import sys

SOLO_WIDTH = "100%"
PAIR_WIDTH = "50%"


def columns_by_workspace(windows: dict[int, dict]) -> dict[int, dict[int, list[int]]]:
    """{workspace: {coluna: [ids]}} só com janelas lado a lado (sem flutuantes)."""
    out: dict[int, dict[int, list[int]]] = {}
    for w in windows.values():
        pos = (w.get("layout") or {}).get("pos_in_scrolling_layout")
        if w.get("is_floating") or w.get("workspace_id") is None or not pos:
            continue
        out.setdefault(w["workspace_id"], {}).setdefault(pos[0], []).append(w["id"])
    return out


def decide(windows: dict[int, dict], widened: set[int]) -> tuple[list[tuple[int, str]], set[int]]:
    """Devolve ([(id, largura), ...], novo conjunto de janelas alargadas por nós)."""
    actions: list[tuple[int, str]] = []
    still: set[int] = set()
    for cols in columns_by_workspace(windows).values():
        ids = [i for col in cols.values() for i in col]
        if len(cols) == 1:
            if not any(i in widened for i in ids):
                actions.append((ids[0], SOLO_WIDTH))
            still.update(ids)
        else:
            for col in cols.values():
                if any(i in widened for i in col):
                    actions.append((col[0], PAIR_WIDTH))
    return actions, still


def apply_event(windows: dict[int, dict], event: dict) -> bool:
    """Atualiza o estado com um evento. True se o layout pode ter mudado."""
    if "WindowsChanged" in event:
        windows.clear()
        windows.update({w["id"]: w for w in event["WindowsChanged"]["windows"]})
    elif "WindowOpenedOrChanged" in event:
        w = event["WindowOpenedOrChanged"]["window"]
        windows[w["id"]] = w
    elif "WindowClosed" in event:
        windows.pop(event["WindowClosed"]["id"], None)
    elif "WindowLayoutsChanged" in event:
        for wid, layout in event["WindowLayoutsChanged"]["changes"]:
            if wid in windows:
                windows[wid]["layout"] = layout
    else:
        return False
    return True


def main() -> int:
    windows: dict[int, dict] = {}
    widened: set[int] = set()
    proc = subprocess.Popen(["niri", "msg", "-j", "event-stream"], stdout=subprocess.PIPE, text=True)
    for line in proc.stdout:
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not apply_event(windows, event):
            continue
        actions, widened = decide(windows, widened)
        for wid, width in actions:
            subprocess.run(["niri", "msg", "action", "set-window-width", "--id", str(wid), width],
                           capture_output=True)
    return proc.wait()


if __name__ == "__main__":
    sys.exit(main())
