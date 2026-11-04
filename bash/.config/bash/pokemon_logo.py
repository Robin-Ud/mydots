#!/usr/bin/env python3
"""Pokémon aleatório + fastfetch ao abrir o terminal (chamado pelo .bashrc).

No kitty, o sprite do krabby (arte ANSI em meio-bloco ▀▄, 1 caractere = 2
pixels) vira PNG e o kitty desenha como IMAGEM com altura fixa em linhas:
fica pequeno e nítido em qualquer tamanho de fonte, e nunca quebra a linha.
Fora do kitty, cai na arte em texto, sorteando só um Pokémon que caiba.

Só stdlib. Uso: pokemon_logo.py [linhas]   (padrão 9, a altura das infos)
"""

import fcntl
import os
import re
import shutil
import struct
import subprocess
import sys
import termios
import time
import zlib

LARGURA_INFO = 30        # colunas do bloco de infos do fastfetch (27) + respiro
MIN_LINHAS = 5           # menor altura em que o sprite ainda é reconhecível
CONFIG = "pokemon"       # ~/.config/fastfetch/pokemon.jsonc
ESC = re.compile(r"\x1b\[([0-9;]*)m")


def sprite_ansi():
    return subprocess.run(
        ["krabby", "random", "--no-title"], capture_output=True, text=True
    ).stdout


def ansi_para_pixels(texto):
    """Arte ANSI em meio-bloco -> matriz de pixels (r, g, b) ou None (transparente)."""
    linhas = texto.rstrip("\n").split("\n")
    img = []
    for linha in linhas:
        cima, baixo = [], []
        fg = bg = None
        pos = 0
        while pos < len(linha):
            m = ESC.match(linha, pos)
            if m:
                cod = [int(c) for c in m.group(1).split(";") if c] or [0]
                i = 0
                while i < len(cod):
                    if cod[i] == 0:
                        fg = bg = None
                    elif cod[i] in (38, 48) and i + 4 < len(cod) and cod[i + 1] == 2:
                        cor = tuple(cod[i + 2:i + 5])
                        if cod[i] == 38:
                            fg = cor
                        else:
                            bg = cor
                        i += 4
                    elif cod[i] == 39:
                        fg = None
                    elif cod[i] == 49:
                        bg = None
                    i += 1
                pos = m.end()
                continue
            ch = linha[pos]
            if ch == "▀":
                cima.append(fg); baixo.append(bg)
            elif ch == "▄":
                cima.append(bg); baixo.append(fg)
            elif ch == "█":
                cima.append(fg); baixo.append(fg)
            else:
                cima.append(bg); baixo.append(bg)
            pos += 1
        img += [cima, baixo]
    larg = max((len(l) for l in img), default=0)
    img = [l + [None] * (larg - len(l)) for l in img]
    return recortar(img)


def recortar(img):
    """Tira as bordas transparentes."""
    ys = [y for y, l in enumerate(img) if any(p is not None for p in l)]
    if not ys:
        return []
    xs = [x for l in img for x, p in enumerate(l) if p is not None]
    x0, x1 = min(xs), max(xs) + 1
    return [l[x0:x1] for l in img[ys[0]:ys[-1] + 1]]


def png(img, escala):
    """PNG RGBA ampliado por vizinho mais próximo (pixel art continua nítido)."""
    linhas = []
    for l in img:
        px = b"".join(
            (bytes(p) + b"\xff" if p else b"\0\0\0\0") * escala for p in l
        )
        linhas += [b"\0" + px] * escala
    w, h = len(img[0]) * escala, len(img) * escala

    def chunk(tipo, dados):
        c = tipo + dados
        return struct.pack(">I", len(dados)) + c + struct.pack(">I", zlib.crc32(c))

    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"".join(linhas), 6))
            + chunk(b"IEND", b""))


def tamanho_celula():
    """(largura, altura) de uma célula em pixels, ou None se o terminal não informa."""
    try:
        with open("/dev/tty") as tty:
            lin, col, xp, yp = struct.unpack(
                "HHHH", fcntl.ioctl(tty, termios.TIOCGWINSZ, b"\0" * 8))
    except OSError:
        return None
    if not (lin and col and xp and yp):
        return None
    return xp / col, yp / lin


def colunas_do_logo(img, linhas, celula):
    """Quantas colunas o sprite ocupa desenhado com `linhas` de altura."""
    cw, ch = celula
    return max(1, round(len(img[0]) * (linhas * ch / len(img)) / cw))


def modo_imagem(linhas, colunas_term):
    celula = tamanho_celula()
    if not celula:
        return False
    img = ansi_para_pixels(sprite_ansi())
    if not img:
        return False
    # janela estreita (coluna do niri): encolhe o sprite até caber do lado das infos
    while linhas > MIN_LINHAS and colunas_do_logo(img, linhas, celula) + LARGURA_INFO > colunas_term:
        linhas -= 1
    cols = colunas_do_logo(img, linhas, celula)
    escala = max(1, -(-int(linhas * celula[1]) // len(img)))  # teto
    # O fastfetch só manda o CAMINHO pro kitty (t=f), e o kitty lê o arquivo
    # depois, no tempo dele: apagar logo em seguida corre o risco de sumir com
    # a imagem antes do desenho. Então cada execução limpa as de >30 s atrás.
    pasta = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "pokemon-logo")
    os.makedirs(pasta, exist_ok=True)
    agora = time.time()
    for velho in os.scandir(pasta):
        try:
            if agora - velho.stat().st_mtime > 30:
                os.remove(velho.path)
        except OSError:
            pass
    destino = os.path.join(pasta, f"{os.getpid()}.png")
    with open(destino, "wb") as f:
        f.write(png(img, escala))
    cmd = ["fastfetch", "-c", CONFIG, "--logo-type", "kitty-direct",
           "--logo", destino, "--logo-width", str(cols), "--logo-height", str(linhas)]
    if cols + LARGURA_INFO > colunas_term:
        cmd += ["--structure", "break"]   # janela estreita: só o Pokémon
    subprocess.run(cmd)
    return True


def modo_texto(colunas_term, max_linhas=12, tentativas=40):
    """Sorteia até achar um sprite que caiba ao lado das infos."""
    sem_cor = lambda s: ESC.sub("", s)
    for _ in range(tentativas):
        arte = sprite_ansi()
        ls = arte.rstrip("\n").split("\n")
        larg = max(len(sem_cor(l)) for l in ls)
        if len(ls) <= max_linhas and larg + LARGURA_INFO <= colunas_term:
            subprocess.run(["fastfetch", "-c", CONFIG, "--logo-type", "file-raw", "--logo", "-"], input=arte, text=True)
            return
    subprocess.run(["fastfetch", "-c", CONFIG, "--logo", "none"])


def main():
    linhas = int(sys.argv[1]) if len(sys.argv) > 1 else 6
    colunas_term = shutil.get_terminal_size().columns
    if os.environ.get("TERM") == "xterm-kitty" and modo_imagem(linhas, colunas_term):
        return
    modo_texto(colunas_term)


if __name__ == "__main__":
    main()
