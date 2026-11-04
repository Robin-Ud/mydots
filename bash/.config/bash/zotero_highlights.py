#!/usr/bin/env python3
"""Extrai highlights (+ notas) de PDFs anotados pelo Zotero para um CSV único.

Uso: zotero_highlights.py <pasta-com-pdfs-recursiva> <saida.csv>
Chamado pela função `flatpdfs -z` do .bashrc.
"""
import csv
import sys
from pathlib import Path

import fitz  # PyMuPDF

CORES_ZOTERO = {
    "yellow": (255, 212, 0),
    "red": (255, 102, 102),
    "green": (95, 178, 54),
    "blue": (46, 168, 229),
    "purple": (162, 138, 229),
    "magenta": (229, 110, 238),
    "orange": (241, 152, 55),
    "gray": (170, 170, 170),
}


def nome_cor(rgb):
    if not rgb:
        return ""
    r, g, b = (round(c * 255) for c in rgb)
    return min(
        CORES_ZOTERO,
        key=lambda nome: sum((a - b) ** 2 for a, b in zip(CORES_ZOTERO[nome], (r, g, b))),
    )


def texto_do_highlight(page, annot):
    pontos = annot.vertices
    if not pontos:
        return ""
    n_quads = len(pontos) // 4
    partes = []
    for i in range(n_quads):
        quad = fitz.Quad(pontos[i * 4 : i * 4 + 4])
        palavras = page.get_text("words", clip=quad.rect)
        partes.append(" ".join(w[4] for w in palavras))
    return " ".join(p for p in partes if p).strip()


def extrair(pdf_path):
    doc = fitz.open(pdf_path)
    linhas = []
    for page in doc:
        for annot in page.annots() or []:
            if annot.type[0] != 8:  # 8 = Highlight
                continue
            texto = texto_do_highlight(page, annot)
            if not texto:
                continue
            cor = nome_cor(annot.colors.get("stroke"))
            nota = (annot.info.get("content") or "").strip()
            linhas.append((page.number + 1, cor, texto, nota))
    doc.close()
    return linhas


def main():
    if len(sys.argv) != 3:
        print("Uso: zotero_highlights.py <pasta> <saida.csv>", file=sys.stderr)
        sys.exit(1)

    pasta = Path(sys.argv[1])
    saida = Path(sys.argv[2])

    with saida.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["paper", "pagina", "cor", "texto", "nota"])
        total = 0
        for pdf in sorted(pasta.rglob("*.pdf")):
            paper = pdf.stem
            linhas = extrair(pdf)
            for pagina, cor, texto, nota in linhas:
                writer.writerow([paper, pagina, cor, texto, nota])
            if linhas:
                print(f"  {paper}: {len(linhas)} highlights")
            total += len(linhas)

    print(f"→ {saida} ({total} highlights)")


if __name__ == "__main__":
    main()
