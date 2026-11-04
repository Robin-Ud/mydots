#!/usr/bin/env python3
"""app — abre um app ou acha a janela que já está aberta (app-here/app-goto do Hyprland).

Uso: app.py here|goto <app_id> <comando...>

  here  traz a janela do app pro workspace onde você está e foca (Alt+letra)
  goto  vai até o workspace onde a janela está e foca (Alt+Shift+letra)

Sem janela aberta, roda o comando. Flatpak demora uns segundos pra mostrar a
janela: apertar de novo nesse meio-tempo não sobe outra instância (10 s de
trava, mesmo arquivo de trava do app-here.sh do Hyprland).
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time

DEBOUNCE = 10  # segundos
RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")


def find(windows: list[dict], app_id: str) -> dict | None:
    """A janela do app usada por último (app_id exato; senão ignorando maiúsculas)."""
    for same in (lambda a: a == app_id, lambda a: a.lower() == app_id.lower()):
        hits = [w for w in windows if same(w.get("app_id") or "")]
        if hits:
            return max(hits, key=lambda w: tuple((w.get("focus_timestamp") or {}).values()) or (0,))
    return None


def plan(mode: str, win: dict | None, workspaces: list[dict]) -> list[list[str]] | None:
    """Ações do niri a rodar; None = não tem janela, tem que abrir o app."""
    if win is None:
        return None
    focus = ["focus-window", "--id", str(win["id"])]
    if mode == "goto":
        return [focus]
    here = next((w for w in workspaces if w.get("is_focused")), None)
    there = next((w for w in workspaces if w["id"] == win["workspace_id"]), None)
    if here is None or there is None or here["id"] == there["id"]:
        return [focus]
    if there["output"] != here["output"]:
        # vai pro workspace ativo do monitor de cá, que é justamente o atual
        return [["move-window-to-monitor", "--id", str(win["id"]), here["output"]], focus]
    return [["move-window-to-workspace", "--window-id", str(win["id"]),
             "--focus", "false", str(here["idx"])], focus]


def recently_launched(stamp: str, now: float, debounce: int = DEBOUNCE) -> bool:
    try:
        return now - os.stat(stamp).st_mtime < debounce
    except OSError:
        return False


def niri(*args: str) -> str:
    return subprocess.run(["niri", "msg", *args], capture_output=True, text=True).stdout


def main() -> int:
    if len(sys.argv) < 4 or sys.argv[1] not in ("here", "goto"):
        print(__doc__, file=sys.stderr)
        return 2
    mode, app_id, cmd = sys.argv[1], sys.argv[2], sys.argv[3:]
    try:
        windows = json.loads(niri("-j", "windows"))
        workspaces = json.loads(niri("-j", "workspaces"))
    except json.JSONDecodeError:
        return 1

    actions = plan(mode, find(windows, app_id), workspaces)
    if actions is not None:
        for action in actions:
            niri("action", *action)
        return 0

    stamp = os.path.join(RUNTIME, f"app-here-{app_id}.stamp")
    if recently_launched(stamp, time.time()):
        return 0
    with open(stamp, "a"):
        os.utime(stamp)
    subprocess.Popen(cmd, start_new_session=True,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return 0


if __name__ == "__main__":
    sys.exit(main())
