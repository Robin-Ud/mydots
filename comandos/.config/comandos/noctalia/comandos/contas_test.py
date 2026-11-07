#!/usr/bin/env python3
"""Testes do contas.py: LaTeX → valor, e o que tem que ser recusado."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from contas import conta  # noqa: E402

CERTO = [
    (r"\sqrt{25}", "5"),
    (r"\sqrt[3]{27}", "3"),
    (r"\frac{1}{2}+\frac{1}{3}", "0,8333333333"),
    (r"\frac12", "0,5"),
    (r"\dfrac{3}{4}\cdot 8", "6"),
    (r"2^{10}", "1024"),
    (r"2^10", "1024"),
    (r"\binom{5}{2}", "10"),
    (r"5!", "120"),
    (r"(2+1)!", "6"),
    (r"2,5\cdot 4", "10"),
    (r"2\pi", "6,283185307"),
    (r"\left(1+2\right)\times 3", "9"),
    (r"3(4)", "12"),
    (r"2\sqrt{2}", "2,828427125"),
    (r"|-3|+1", "4"),
    (r"\ln{e}", "1"),
    (r"\log{1000}", "3"),
    (r"\sin{\frac{\pi}{2}}", "1"),
    ("√25", "5"),
    ("√(9+16)", "5"),
    ("3² + 4²", "25"),
    ("10 ÷ 4", "2,5"),
    ("2 × π", "6,283185307"),
    (r"\frac{1}{3} =", "0,3333333333"),
    ("50\\%", "0,5"),
    ("1e3 + 1", "1001"),
]

ERRADO = [
    "xy + 1",               # duas letras grudadas: escrever "x y"
    "v1-capim",             # palavra não é variável
    "__import__('os')",
    "9**9**9",
    "1/0",
    r"\sqrt{-1}",
    r"\frac{1}{",
    r"\foo{2}",
    "1001!",
    "",
]

# com variável (sympy): compara o título que aparece no launcher
SIMBOLICO = [
    (r"\sqrt{25} \cdot x", "= 5·x"),
    (r"2\pi r", "= 2·π·r"),
    (r"\frac{x}{2}+\frac{x}{3}", "= 5·x/6"),
    (r"2\alpha + 3\alpha", "= 5·α"),
    ("x y + y x", "= 2·x·y"),
    (r"\sin{x}^2+\cos{x}^2", "= 1"),
    ("2x+3=7", "x = 2"),
    ("0,5x=2", "x = 4"),
    ("x^2-5x+6=0", "x = 2 ou x = 3"),
    ("x^2=2", "x = -√2 ≈ -1,41421 ou x = √2 ≈ 1,41421"),
    ("x^2+1=0", "x = -i ou x = i"),
    ("3x = 3x", "verdadeiro"),
    ("2y = 4 + y", "y = 4"),
]

try:
    import sympy  # noqa: F401
except ImportError:
    print("  (sem sympy: pulando os testes com variável)")
    SIMBOLICO = []

falhas = 0
for entrada, esperado in SIMBOLICO:
    r = conta(entrada)
    if r.get("titulo") == esperado:
        print(f"  ok  {entrada!r} → {esperado}")
    else:
        falhas += 1
        print(f"  ERRO {entrada!r}: esperava {esperado!r}, veio {r}")
for entrada, esperado in CERTO:
    r = conta(entrada)
    if r.get("valor") == esperado:
        print(f"  ok  {entrada!r} = {esperado}")
    else:
        falhas += 1
        print(f"  ERRO {entrada!r}: esperava {esperado}, veio {r}")
for entrada in ERRADO:
    r = conta(entrada)
    if not r["ok"]:
        print(f"  ok  {entrada!r} recusado ({r['erro']})")
    else:
        falhas += 1
        print(f"  ERRO {entrada!r} devia ser recusado, veio {r}")

print()
print("tudo certo" if not falhas else f"{falhas} falha(s)")
sys.exit(1 if falhas else 0)
