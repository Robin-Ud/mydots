#!/usr/bin/env python3
"""cola — a cola de atalhos do niri, no estilo -h / man.

Uso:
  cola.py resumo   (Super+/)        o "-h": seco, uma linha por atalho, sem o dia a dia
  cola.py tudo     (Super+Shift+/)  o "man": tudo, com explicação e busca
  cola.py socorro                   terminal com Claude Code de guia pra visitas

Apertar o mesmo atalho de novo fecha; o outro troca de modo. Esc fecha.
Clicar numa linha FAZ a ação: a cola fecha, o foco volta pra janela em que
você estava e o niri executa (via `niri msg action`). No man, Enter na busca
faz o primeiro resultado. Apagar wallpaper e sair do niri pedem confirmação.

Socorro (botão nas duas telas): abre o kitty com o Claude Code no modo "guia
pra visitantes" (prompt em socorro.md). Roda numa pasta vazia própria, pra não
carregar memória nem permissões dos projetos do Matheus; modo manual (pede
permissão), sem Write/Edit, e só o `niri msg` liberado sem perguntar.

As duas leem o config.kdl ao lado, então mudou o config, a cola muda junto:
  - cada bind com hotkey-overlay-title vira uma linha;
  - binds com title=null logo abaixo viram "também: ..." dessa linha;
  - a seção é o 1º comentário depois de uma linha em branco, e o bloco de
    comentário inteiro vira a explicação da seção no "man";
  - comentário no meio da seção vira explicação do bind logo abaixo.

DIARIO (abaixo) é o que você já faz sem pensar: some do -h, fica no man.
"""

from __future__ import annotations

import os
import re
import signal
import subprocess
import sys
import unicodedata

AQUI = os.path.dirname(os.path.realpath(__file__))
CONFIG = os.path.join(AQUI, "config.kdl")
SOCORRO_MD = os.path.join(AQUI, "socorro.md")
SOCORRO_DIR = os.path.expanduser("~/.local/share/socorro-niri")
PIDFILE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "cola-niri.pid")

# O que já está no dedo: some do -h (vai pra uma linha apagada no rodapé).
# Tecla como está no config.kdl. O cola_test.py confere que todas existem.
DIARIO = [
    "Mod+Return", "Alt+Return", "Mod+D", "Mod+Q", "Mod+F", "Mod+Space",
    "Mod+H", "Mod+L", "Mod+J", "Mod+K",
    "Mod+Shift+H", "Mod+Shift+L", "Mod+Shift+J", "Mod+Shift+K",
    "Mod+1", "Mod+Shift+1", "Mod+Tab", "Mod+Shift+Tab", "Alt+Tab", "Alt+Shift+Tab",
    "Mod+Slash", "Mod+Shift+Slash", "Print",
]

# Não têm `niri msg action` (só funcionam pelo teclado): a linha não é clicável
SO_TECLADO = {"next-window", "previous-window", "show-hotkey-overlay"}

# Clique nesses pede "tem certeza?"
CONFIRMAR = {"Mod+Shift+W", "Mod+Shift+E"}

# Binds sem hotkey-overlay-title (o bloco recent-windows não aceita title)
ACOES = {
    "next-window": "Janela usada por último (segura Super e vai apertando Tab)",
    "previous-window": "Janela usada por último, no sentido contrário",
}

NOMES_TECLA = {
    "Mod": "Super", "Return": "Enter", "Space": "Espaço", "Escape": "Esc",
    "Slash": "/", "Comma": ",", "Period": ".", "Minus": "-", "Equal": "=",
    "grave": "`", "Left": "←", "Right": "→", "Up": "↑", "Down": "↓",
    "WheelScrollDown": "roda ↓", "WheelScrollUp": "roda ↑",
    "WheelScrollLeft": "roda ←", "WheelScrollRight": "roda →",
    "XF86AudioRaiseVolume": "Vol +", "XF86AudioLowerVolume": "Vol −",
    "XF86AudioMute": "Mudo", "XF86AudioMicMute": "Mic mudo",
    "XF86MonBrightnessUp": "Brilho +", "XF86MonBrightnessDown": "Brilho −",
}


# --- Parte pura (testada) ---------------------------------------------------

def teclas(bind: str) -> list[str]:
    """'Mod+Shift+Left' → ['Super', 'Shift', '←']."""
    return [NOMES_TECLA.get(p, p) for p in bind.split("+")]


def tecla_txt(bind: str) -> str:
    return "+".join(teclas(bind))


def secao(comentario: str) -> str:
    """'// Foco (vim + setas)' → 'Foco'. Corta no primeiro ':' '(' ou ' —'."""
    t = comentario.strip().lstrip("/").strip()
    t = re.split(r"\s*(?::|\(| —)", t, maxsplit=1)[0]
    return t.strip().strip('"') or "Geral"


_BIND = re.compile(r"^\s*([A-Za-z0-9_]+(?:\+[A-Za-z0-9_]+)*)\b([^{]*)\{\s*([\w-]+)(.*)\}")
_TITLE = re.compile(r'hotkey-overlay-title=(null|"((?:[^"\\]|\\.)*)")')


_TOK = re.compile(r'([\w-]+)=(?:"((?:[^"\\]|\\.)*)"|(\S+))|"((?:[^"\\]|\\.)*)"|(\S+)')


def _desescapa(t: str) -> str:
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m[1], m[1]), t)


def comando(acao: str, resto: str) -> list[str] | None:
    """Ação do bind → argv do `niri msg action`, ou None se não dá pra clicar.

    'move-column-to-workspace', ' 9 focus=false; ' →
    ['niri', 'msg', 'action', 'move-column-to-workspace', '--focus', 'false', '--', '9']
    """
    if acao in SO_TECLADO:
        return None
    pos, opts = [], []
    for m in _TOK.finditer(resto.strip().rstrip(";")):
        chave, vq, vb, q, b = m.groups()
        if chave:
            opts += [f"--{chave}", _desescapa(vq) if vq is not None else vb]
        else:
            pos.append(_desescapa(q) if q is not None else b.rstrip(";"))
    argv = ["niri", "msg", "action", acao, *opts]
    return argv + ["--", *pos] if pos else argv


def ler_binds(texto: str) -> list[dict]:
    """Linhas da cola, na ordem do config.

    Cada linha: {secao, bind, titulo, variantes, nota, nota_secao, cmd}.
    nota = comentário logo acima do bind; nota_secao = comentário que abriu a seção.
    """
    linhas: list[dict] = []
    no_binds = False
    pai = ""            # nó de topo onde o binds{} está (binds, recent-windows)
    sec, nota_sec = "Geral", ""
    branco = True
    no_cabecalho = False  # ainda nas linhas do comentário que abriu a seção
    bloco: list[str] = []
    for crua in texto.splitlines():
        s = crua.strip()
        if not no_binds:
            m = re.match(r"^([\w-]+)\s*\{", crua)
            if m:
                pai = m.group(1)
            if re.match(r"^binds\s*\{", s):
                no_binds = True
                sec = "Trocar de janela" if pai == "recent-windows" else "Geral"
                nota_sec, branco, bloco = "", True, []
            continue
        if s == "}":
            no_binds = False
            continue
        if not s:
            branco = True
            continue
        if s.startswith("//"):
            txt = s.lstrip("/").strip()
            if branco:
                sec, nota_sec, no_cabecalho, bloco = secao(s), txt, True, []
            elif no_cabecalho:
                nota_sec += " " + txt
            else:
                bloco.append(txt)
            branco = False
            continue
        branco = no_cabecalho = False
        m = _BIND.match(crua)
        if not m:
            continue
        bind, props, acao, resto = m.groups()
        nota, bloco = " ".join(bloco), []
        t = _TITLE.search(props)
        if t and t.group(1) == "null":
            if linhas and linhas[-1]["secao"] == sec:
                linhas[-1]["variantes"].append(bind)
            continue
        if t:
            titulo = t.group(2).replace('\\"', '"')
        else:
            titulo = ACOES.get(acao, acao.replace("-", " "))
            if 'filter="app-id"' in resto:
                titulo = titulo.split(" (")[0] + ", só do mesmo app"
        linhas.append({"secao": sec, "bind": bind, "titulo": titulo, "variantes": [],
                       "nota": nota, "nota_secao": nota_sec, "cmd": comando(acao, resto)})
    return linhas


def agrupar(linhas: list[dict]) -> list[tuple[str, list[dict]]]:
    """[(seção, linhas)] na ordem em que aparecem."""
    grupos: list[tuple[str, list[dict]]] = []
    for l in linhas:
        if not grupos or grupos[-1][0] != l["secao"]:
            grupos.append((l["secao"], []))
        grupos[-1][1].append(l)
    return grupos


def colunas(grupos: list, n: int) -> list[list]:
    """Divide as seções (sem quebrar nenhuma) em n colunas de altura parecida.

    Altura de uma seção = linhas + 2 (cabeçalho e respiro).
    """
    from itertools import combinations

    altura = [len(ls) + 2 for _, ls in grupos]
    n = max(1, min(n, len(grupos)))
    melhor, cortes = None, ()
    # Poucas seções (~20): testa todos os pontos de corte e fica com a menor coluna mais alta
    for c in combinations(range(1, len(grupos)), n - 1):
        lim = (0, *c, len(grupos))
        pior = max(sum(altura[a:b]) for a, b in zip(lim, lim[1:]))
        if melhor is None or pior < melhor:
            melhor, cortes = pior, c
    lim = (0, *cortes, len(grupos))
    return [grupos[a:b] for a, b in zip(lim, lim[1:])]


def normal(t: str) -> str:
    """Minúsculo e sem acento, pra busca ('Área' acha com 'area')."""
    t = unicodedata.normalize("NFD", t.lower())
    return "".join(c for c in t if unicodedata.category(c) != "Mn")


def texto_busca(linha: dict) -> str:
    partes = [linha["titulo"], linha["secao"], linha.get("nota", "")]
    for b in [linha["bind"], *linha["variantes"]]:
        partes += [b, tecla_txt(b)]
    return normal(" ".join(partes))


def bate(busca: str, alvo: str) -> bool:
    """Toda palavra da busca aparece no alvo (já normalizado)."""
    return all(p in alvo for p in normal(busca).split())


# --- Liga/desliga pelo mesmo atalho -------------------------------------------

def _viva(pid: int) -> bool:
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            return b"cola.py" in f.read()
    except OSError:
        return False


def alternar(modo: str) -> bool:
    """Fecha a cola aberta. True = era o mesmo modo, então só fechar e sair."""
    try:
        pid, aberto = open(PIDFILE).read().split()
        pid = int(pid)
    except (OSError, ValueError):
        return False
    if pid == os.getpid() or not _viva(pid):
        return False
    os.kill(pid, signal.SIGTERM)
    return aberto == modo


def janela_focada() -> int | None:
    """Id da janela focada agora (antes da cola abrir), pra devolver o foco."""
    try:
        r = subprocess.run(["niri", "msg", "-j", "focused-window"], capture_output=True, text=True, timeout=2)
        import json
        return (json.loads(r.stdout) or {}).get("id")
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return None


def executar(cmd: list[str], alvo: int | None) -> None:
    if cmd == ["socorro"]:
        os.makedirs(SOCORRO_DIR, exist_ok=True)
        cmd = socorro_cmd()
    if alvo is not None and "spawn" not in cmd[3]:
        subprocess.run(["niri", "msg", "action", "focus-window", "--id", str(alvo)], capture_output=True)
    subprocess.run(cmd, capture_output=True)


def socorro_cmd() -> list[str]:
    """argv que abre o terminal do guia (pelo niri, pra não morrer junto com a cola)."""
    prompt = open(SOCORRO_MD, encoding="utf-8").read().replace("ATALHOS_CONFIG", CONFIG)
    return ["niri", "msg", "action", "spawn", "--",
            "kitty", "--title", "Socorro", "--directory", SOCORRO_DIR,
            "claude", "--permission-mode", "manual",
            "--disallowedTools", "Write,Edit,NotebookEdit",
            "--allowedTools", "Bash(niri msg:*)",
            "--add-dir", AQUI,
            "--append-system-prompt", prompt,
            "Oi! Abri o socorro."]


def marcar(modo: str) -> None:
    with open(PIDFILE, "w") as f:
        f.write(f"{os.getpid()} {modo}")


# --- GUI (GTK4, como a do SetTela) ----------------------------------------------

CSS = """
.cola { padding: 16px 20px; }
.cola-titulo { font-size: 1.25em; font-weight: 800; }
.cola-dica { opacity: .6; font-size: .9em; }
.cola-secao { font-weight: 800; font-size: .78em; letter-spacing: .08em;
              opacity: .55; margin-top: 12px; margin-bottom: 3px; }
.cola-nota-secao { opacity: .6; font-size: .88em; margin-bottom: 6px; }
.cola-cartao { border-radius: 12px; padding: 4px 0;
               background: alpha(currentColor, .045);
               border: 1px solid alpha(currentColor, .09); }
.cola-linha { padding: 6px 14px; }
.cola-tecla { font-family: monospace; font-weight: 700; font-size: .92em;
              padding: 1px 8px; min-width: 14px; border-radius: 6px;
              background: alpha(currentColor, .09);
              border: 1px solid alpha(currentColor, .18);
              border-bottom-width: 3px; }
.cola-mais { opacity: .4; font-weight: 700; }
.cola-tambem { opacity: .55; font-size: .85em; }
.cola-h-tecla { font-family: monospace; font-weight: 700;
                color: @accent_color; }
.cola-h-texto { }
.cola-botao { padding: 0; border-radius: 8px; font-weight: normal; }
.cola-botao:hover { background: alpha(@accent_bg_color, .22); }
.cola-h-linha { padding: 2px 6px; }
.cola-socorro { font-weight: 800; }
.cola-rodape { border-top: 1px solid alpha(currentColor, .12);
               padding-top: 10px; margin-top: 12px; }
.cola-diario { opacity: .4; font-size: .85em; }
"""


def gui(modo: str) -> list[str] | None:
    """Abre a cola; devolve o comando da linha clicada (ou None)."""
    import gi
    gi.require_version("Gtk", "4.0")
    from gi.repository import Gdk, Gio, GLib, Gtk

    estado = {"modo": modo, "acao": None}

    def escolher(l: dict) -> None:
        cmd = l["cmd"]
        if not cmd:
            return
        if any(c.endswith("cola.py") for c in cmd):  # a própria cola: só troca de modo
            trocar(cmd[-1])
            return

        def vai():
            estado["acao"] = cmd
            app.quit()

        if l["bind"] in CONFIRMAR:
            d = Gtk.AlertDialog(message=l["titulo"] + "?", detail="Atalho: " + tecla_txt(l["bind"]),
                                buttons=["Cancelar", "Fazer"], cancel_button=0, default_button=0)
            d.choose(janela, None, lambda d, res: d.choose_finish(res) == 1 and vai())
        else:
            vai()

    def botao_socorro() -> Gtk.Button:
        b = Gtk.Button(label="Socorro: pergunte ao Claude", focusable=False,
                       css_classes=["suggested-action", "cola-socorro"],
                       tooltip_text="Abre um terminal com o Claude de guia: escreva em português o que quer fazer")

        def vai(*_):
            estado["acao"] = ["socorro"]
            app.quit()

        b.connect("clicked", vai)
        return b

    def clicavel(filho: Gtk.Widget, l: dict) -> Gtk.Widget:
        """Embrulha a linha num botão que faz a ação (ou deixa quieta, se não dá)."""
        if not l["cmd"]:
            filho.set_tooltip_text("Só pelo teclado (o niri não deixa disparar isso de fora)")
            filho.set_opacity(0.7)
            return filho
        b = Gtk.Button(child=filho, css_classes=["flat", "cola-botao"],
                       tooltip_text="Clique pra fazer agora", cursor=Gdk.Cursor.new_from_name("pointer"))
        b.connect("clicked", lambda *_: escolher(l))
        return b

    def lbl(texto: str, *css: str, **kw) -> Gtk.Label:
        kw.setdefault("xalign", 0)
        return Gtk.Label(label=texto, css_classes=list(css), **kw)

    def caps(bind: str) -> Gtk.Box:
        box = Gtk.Box(spacing=4, valign=Gtk.Align.CENTER)
        for i, t in enumerate(teclas(bind)):
            if i:
                box.append(lbl("+", "cola-mais"))
            box.append(lbl(t, "cola-tecla", xalign=0.5))
        return box

    def ler() -> list[dict] | str:
        try:
            return ler_binds(open(CONFIG, encoding="utf-8").read())
        except OSError as e:
            return f"Não consegui ler {CONFIG}:\n{e}"

    # -- o "-h": denso, sem caixinha, sem o dia a dia --
    def tela_resumo() -> Gtk.Widget:
        linhas = ler()
        if isinstance(linhas, str):
            return lbl(linhas)
        diario = set(DIARIO)
        escondidas = [l for l in linhas if l["bind"] in diario]
        visiveis = [l for l in linhas if l["bind"] not in diario]

        raiz = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, css_classes=["cola"])
        topo = Gtk.Box(spacing=12)
        topo.append(lbl("Atalhos  -h", "cola-titulo", hexpand=True))
        topo.append(lbl("clique pra fazer  ·  Super+Shift+/  completo, com busca  ·  Esc fecha", "cola-dica"))
        topo.append(botao_socorro())
        raiz.append(topo)

        faixa = Gtk.Box(spacing=20, homogeneous=True)
        for col in colunas(agrupar(visiveis), 3):
            cbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
            grupo = Gtk.SizeGroup(mode=Gtk.SizeGroupMode.HORIZONTAL)
            for nome, ls in col:
                cbox.append(lbl(nome.upper(), "cola-secao"))
                for l in ls:
                    row = Gtk.Box(spacing=12, css_classes=["cola-h-linha"])
                    k = lbl(tecla_txt(l["bind"]), "cola-h-tecla", valign=Gtk.Align.START)
                    grupo.add_widget(k)
                    row.append(k)
                    row.append(lbl(l["titulo"], "cola-h-texto", wrap=True, max_width_chars=30, hexpand=True))
                    cbox.append(clicavel(row, l))
            faixa.append(cbox)
        # Cresce até o tamanho natural, mas nunca passa de 85% da menor tela (monitor 1080p)
        mons = Gdk.Display.get_default().get_monitors()
        alt = min((mons.get_item(i).get_geometry().height for i in range(mons.get_n_items())), default=900)
        rolagem = Gtk.ScrolledWindow(hscrollbar_policy=Gtk.PolicyType.NEVER, propagate_natural_height=True,
                                     propagate_natural_width=True, max_content_height=int(alt * 0.85) - 140)
        rolagem.set_child(faixa)
        raiz.append(rolagem)

        rod = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, css_classes=["cola-rodape"])
        rod.append(lbl("Fora daqui porque já estão no dedo: "
                       + "  ".join(tecla_txt(l["bind"]) for l in escondidas),
                       "cola-diario", wrap=True, max_width_chars=150))
        raiz.append(rod)
        return raiz

    # -- o "man": tudo, com explicação e busca --
    def tela_tudo() -> Gtk.Widget:
        linhas = ler()
        if isinstance(linhas, str):
            return lbl(linhas)
        raiz = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, css_classes=["cola"])
        topo = Gtk.Box(spacing=12)
        topo.append(lbl("Atalhos  man", "cola-titulo", hexpand=True))
        editar = Gtk.Button(label="Editar no config.kdl", tooltip_text=CONFIG, focusable=False)
        editar.connect("clicked", lambda *_: subprocess.Popen(["code", CONFIG]))
        topo.append(botao_socorro())
        topo.append(editar)
        raiz.append(topo)
        raiz.append(lbl("Digite pra filtrar (\"print\", \"volume\", \"super+s\")  ·  clique numa linha ou Enter"
                        " pra fazer  ·  Esc limpa, depois fecha  ·  Super+/  resumo", "cola-dica", wrap=True))
        busca = Gtk.SearchEntry(placeholder_text="Procurar atalho…", margin_top=10)
        busca.set_key_capture_widget(janela)
        raiz.append(busca)

        lista = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, margin_end=10)
        grupo = Gtk.SizeGroup(mode=Gtk.SizeGroupMode.HORIZONTAL)
        secoes = []  # (caixa da seção, [(linha, texto de busca)])
        for nome, ls in agrupar(linhas):
            cab = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            cab.append(lbl(nome.upper(), "cola-secao"))
            ns = ls[0]["nota_secao"]
            if ns and normal(ns) != normal(nome):
                cab.append(lbl(ns, "cola-nota-secao", wrap=True))
            cartao = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, css_classes=["cola-cartao"])
            cab.append(cartao)
            lista.append(cab)
            itens = []
            for l in ls:
                row = Gtk.Box(spacing=16, css_classes=["cola-linha"])
                k = caps(l["bind"])
                grupo.add_widget(k)
                row.append(k)
                txt = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, valign=Gtk.Align.CENTER, hexpand=True)
                txt.append(lbl(l["titulo"], wrap=True))
                if l["nota"]:
                    txt.append(lbl(l["nota"], "cola-tambem", wrap=True))
                v = l["variantes"]
                if v:
                    mostra = ", ".join(tecla_txt(b) for b in v[:4])
                    txt.append(lbl("também: " + mostra + (f" e mais {len(v) - 4}" if len(v) > 4 else ""),
                                   "cola-tambem", wrap=True))
                row.append(txt)
                w = clicavel(row, l)
                cartao.append(w)
                itens.append((w, texto_busca(l), l))
            secoes.append((cab, itens))
        vazio = lbl("Nenhum atalho com isso.", "cola-dica", xalign=0.5, margin_top=24, visible=False)
        lista.append(vazio)

        def filtrar(*_):
            q = busca.get_text()
            algum = False
            for cab, itens in secoes:
                vis = 0
                for w, alvo, _ in itens:
                    ok = bate(q, alvo)
                    w.set_visible(ok)
                    vis += ok
                cab.set_visible(vis > 0)
                algum |= vis > 0
            vazio.set_visible(not algum)

        def esc(*_):
            if busca.get_text():
                busca.set_text("")
            else:
                app.quit()

        def enter(*_):
            # Enter na busca = faz o primeiro resultado clicável
            for cab, itens in secoes:
                for w, _, l in itens:
                    if w.get_visible() and cab.get_visible() and l["cmd"]:
                        escolher(l)
                        return

        busca.connect("activate", enter)
        busca.connect("search-changed", filtrar)
        busca.connect("stop-search", esc)
        rolagem = Gtk.ScrolledWindow(vexpand=True, hscrollbar_policy=Gtk.PolicyType.NEVER, margin_top=6)
        rolagem.set_child(lista)
        raiz.append(rolagem)
        GLib.idle_add(busca.grab_focus)
        return raiz

    def trocar(novo: str) -> None:
        estado["modo"] = novo
        marcar(novo)
        if novo == "tudo":
            janela.set_default_size(800, 880)
            janela.set_child(tela_tudo())
        else:
            janela.set_default_size(-1, -1)
            janela.set_child(tela_resumo())

    def ao_ativar(_app):
        nonlocal janela
        css = Gtk.CssProvider()
        css.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), css,
                                                  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        janela = Gtk.ApplicationWindow(application=_app, title="Atalhos")
        teclado = Gtk.EventControllerKey()

        def tecla(_c, kv, _code, _mods):
            # No man o Esc é da busca (limpa, depois fecha); no -h fecha direto
            if kv == Gdk.KEY_Escape and estado["modo"] == "resumo":
                _app.quit()
                return True
            return False

        teclado.connect("key-pressed", tecla)
        janela.add_controller(teclado)
        trocar(estado["modo"])
        janela.present()

    janela = None
    app = Gtk.Application(application_id="rud.cola", flags=Gio.ApplicationFlags.NON_UNIQUE)
    app.connect("activate", ao_ativar)
    app.run([sys.argv[0]])
    return estado["acao"]


def main() -> int:
    modo = sys.argv[1] if len(sys.argv) > 1 else "resumo"
    if modo == "socorro":
        executar(["socorro"], None)
        return 0
    if modo not in ("resumo", "tudo"):
        print(__doc__.strip().split("\n\n")[1], file=sys.stderr)
        return 2
    if alternar(modo):
        return 0
    alvo = janela_focada()
    marcar(modo)
    try:
        cmd = gui(modo)
        if cmd:
            executar(cmd, alvo)
    finally:
        try:
            if open(PIDFILE).read().split()[0] == str(os.getpid()):
                os.remove(PIDFILE)
        except (OSError, IndexError):
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
