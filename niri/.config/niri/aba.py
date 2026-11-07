#!/usr/bin/env python3
"""aba — Mod+Shift+Enter: nova aba no kitty focado, na mesma pasta.

Uso: aba.py          nova aba (Mod+Shift+Enter)
     aba.py nome     renomear a aba atual (Mod+Shift+R): abre o prompt do kitty

Se a janela focada é um kitty, pede pra ele (remote control, socket
$XDG_RUNTIME_DIR/kitty-<pid>, do listen_on do kitty.conf) abrir uma aba com a
pasta atual. Se não é kitty, ou o socket falhar, abre um kitty novo, igual ao
Mod+Enter. No modo "nome", se não é kitty, não faz nada.
Dentro do terminal, `aba NOME` (scripts/.local/bin) faz o mesmo sem prompt.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys

RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")


def socket_for(win: dict | None) -> str | None:
    """Socket do kitty dono da janela focada; None se não for kitty."""
    if not win or win.get("app_id") != "kitty" or not win.get("pid"):
        return None
    return f"{RUNTIME}/kitty-{win['pid']}"


def main(argv: list[str]) -> None:
    rename = argv[:1] == ["nome"]
    try:
        out = subprocess.run(["niri", "msg", "-j", "focused-window"],
                             capture_output=True, text=True, timeout=2).stdout
        win = json.loads(out or "null")
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError):
        win = None
    sock = socket_for(win)
    ok = bool(sock) and os.path.exists(sock)
    if rename:
        if ok:
            subprocess.run(["kitty", "@", "--to", f"unix:{sock}", "action",
                            "set_tab_title"], capture_output=True, timeout=3)
        return
    if ok:
        r = subprocess.run(["kitty", "@", "--to", f"unix:{sock}", "launch",
                            "--type=tab", "--cwd=oldest"],
                           capture_output=True, timeout=3)
        if r.returncode == 0:
            return
    subprocess.Popen(["kitty"], start_new_session=True)


if __name__ == "__main__":
    main(sys.argv[1:])
