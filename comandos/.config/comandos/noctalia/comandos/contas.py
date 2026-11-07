#!/usr/bin/env python3
"""contas — conta em LaTeX (ou com √ π × ÷ ²) pro launcher da noctalia.

Uso: contas.py '\\frac{1}{2}+\\sqrt{25}'
     → {"ok": true, "valor": "5,5", "expr": "((1)/(2))+sqrt(25)"}

Traduz o LaTeX pra uma expressão Python e avalia com o ast, só com números,
operadores e as funções da lista branca (nada de eval cru). Puro Python, zero deps.

Com variável (letra solta: x, y, \\alpha…) entra o sympy, se estiver instalado:
     \\sqrt{25}\\cdot x  → = 5·x
     2x+3=7            → x = 2
     x^2=2             → x = -√2 ≈ -1,414 ou x = √2 ≈ 1,414
O mesmo caminhador do ast monta a expressão com objetos do sympy, então continua sem eval.
"""

from __future__ import annotations

import ast
import json
import math
import operator
import re
import sys

FUNCS = {
    "sqrt": math.sqrt, "cbrt": lambda x: math.copysign(abs(x) ** (1 / 3), x),
    "sin": math.sin, "cos": math.cos, "tan": math.tan,
    "asin": math.asin, "acos": math.acos, "atan": math.atan,
    "sinh": math.sinh, "cosh": math.cosh, "tanh": math.tanh,
    "log": math.log, "log10": math.log10, "log2": math.log2, "exp": math.exp,
    "abs": abs, "factorial": None, "comb": None,  # os dois com limite, abaixo
}
CONSTS = {"pi": math.pi, "e": math.e, "tau": math.tau}

GREGOS = {"alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "theta": "θ",
          "lambda": "λ", "mu": "μ", "sigma": "σ", "phi": "φ", "omega": "ω", "rho": "ρ"}

# \comando → texto Python (os que levam argumento ficam no _conv). Nome vai com espaço
# em volta pra não grudar no vizinho (\pi\pi, \alpha x).
SIMPLES = {
    "cdot": "*", "times": "*", "div": "/", "pi": " pi ", "tau": " tau ",
    "sin": " sin", "cos": " cos", "tan": " tan", "arcsin": " asin", "arccos": " acos",
    "arctan": " atan", "sinh": " sinh", "cosh": " cosh", "tanh": " tanh",
    "ln": " log", "log": " log10", "exp": " exp", "left": "", "right": "",
    ",": "", ";": "", "!": "", " ": "", "quad": "", "%": "/100",
    **{g: f" {g} " for g in GREGOS},
}
UNICODE = {"×": "*", "·": "*", "⋅": "*", "÷": "/", "π": "pi", "−": "-", "²": "^2", "³": "^3"}


class ContaInvalida(ValueError):
    pass


def _grupo(s: str, i: int) -> tuple[str, int]:
    """Argumento a partir de s[i]: {…} balanceado, ou um só caractere/\\comando."""
    while i < len(s) and s[i] == " ":
        i += 1
    if i >= len(s):
        raise ContaInvalida("faltou argumento")
    if s[i] == "{":
        nivel, j = 0, i
        while j < len(s):
            nivel += {"{": 1, "}": -1}.get(s[j], 0)
            if nivel == 0:
                return s[i + 1:j], j + 1
            j += 1
        raise ContaInvalida("chave sem fechar")
    if s[i] == "\\":
        m = re.match(r"\\[A-Za-z]+", s[i:])
        if m:
            return m.group(), i + m.end()
    return s[i], i + 1


def _conv(s: str) -> str:
    """LaTeX → Python, recursivo nos argumentos de \\frac, \\sqrt e \\binom."""
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == "\\":
            m = re.match(r"\\([A-Za-z]+|.)", s[i:])
            nome, i = m.group(1), i + m.end()
            if nome in ("frac", "dfrac", "tfrac"):
                a, i = _grupo(s, i)
                b, i = _grupo(s, i)
                out.append(f"(({_conv(a)})/({_conv(b)}))")
            elif nome == "sqrt":
                n = None
                if i < len(s) and s[i] == "[":
                    fim = s.find("]", i)
                    if fim < 0:
                        raise ContaInvalida("colchete sem fechar")
                    n, i = s[i + 1:fim], fim + 1
                a, i = _grupo(s, i)
                out.append(f"sqrt({_conv(a)})" if n is None else f"(({_conv(a)})**(1/({_conv(n)})))")
            elif nome == "binom":
                a, i = _grupo(s, i)
                b, i = _grupo(s, i)
                out.append(f"comb({_conv(a)}, {_conv(b)})")
            elif nome in SIMPLES:
                out.append(SIMPLES[nome])
            else:
                raise ContaInvalida(f"não sei \\{nome}")
        elif c == "√":
            a, i = _grupo(s, i + 1)
            if a == "(":  # √(…): pega até o parêntese que fecha
                nivel, j = 1, i
                while j < len(s) and nivel:
                    nivel += {"(": 1, ")": -1}.get(s[j], 0)
                    j += 1
                a, i = s[i:j - 1], j
            elif a.isdigit():  # √25: o número inteiro
                m = re.match(r"[\d.]*", s[i:])
                a, i = a + m.group(), i + m.end()
            out.append(f"sqrt({_conv(a)})")
        elif c == "{":
            out.append("(")
            i += 1
        elif c == "}":
            out.append(")")
            i += 1
        else:
            out.append(UNICODE.get(c, c))
            i += 1
    return "".join(out)


def _modulo(s: str) -> str:
    """|x| → abs(x), alternando abre/fecha."""
    out, aberto = [], False
    for c in s:
        if c == "|":
            out.append(")" if aberto else "abs(")
            aberto = not aberto
        else:
            out.append(c)
    return "".join(out)


def _fatorial(s: str) -> str:
    """n! e (…)! → factorial(…)."""
    while "!" in s:
        k = s.index("!")
        if k == 0:
            raise ContaInvalida("! solto")
        if s[k - 1] == ")":
            nivel, j = 0, k - 1
            while j >= 0:
                nivel += {")": 1, "(": -1}.get(s[j], 0)
                if nivel == 0:
                    break
                j -= 1
            # se o parêntese é de uma função (sqrt(…)!), leva o nome junto
            while j > 0 and (s[j - 1].isalnum() or s[j - 1] == "_"):
                j -= 1
        else:
            m = re.search(r"[\w.]+$", s[:k])
            if not m:
                raise ContaInvalida("! solto")
            j = m.start()
        s = s[:j] + f"factorial({s[j:k]})" + s[k + 1:]
    return s


TOKEN = re.compile(r"\s*(?:(\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|([A-Za-z_]\w*)|(\*\*|[-+*/%(),]))")


def _implicita(s: str) -> str:
    """Multiplicação implícita: 2pi, 3(4), )(, 2sqrt(2), pi r."""
    toks, i = [], 0
    s = s.strip()
    while i < len(s):
        m = TOKEN.match(s, i)
        if not m or m.end() == i:
            raise ContaInvalida(f"não entendi '{s[i:].strip()[:10]}'")
        toks.append(m.group(1) or m.group(2) or m.group(3))
        i = m.end()
    out = []
    for t in toks:
        if out:
            a = out[-1]
            esq = a[0].isdigit() or a == ")" or (a[0].isalpha() and a not in FUNCS)
            dir_ = t[0].isdigit() or t == "(" or t[0].isalpha()
            if esq and dir_ and not (a in FUNCS and t == "("):
                out.append("*")
        out.append(t)
    return "".join(out)


def traduz(texto: str) -> str:
    s = texto.strip().rstrip("=").strip()
    s = re.sub(r"(?<=\d),(?=\d)", ".", s)  # vírgula decimal: 2,5
    s = s.replace("**", "^")
    s = _conv(s)
    s = s.replace("^", "**")
    s = _modulo(s)
    s = _fatorial(s)
    return _implicita(s)


OPS = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul,
       ast.Div: operator.truediv, ast.Mod: operator.mod, ast.Pow: operator.pow}


def variaveis(expr: str) -> list[str]:
    """Nomes que não são função nem constante. Só letra solta ou grego vale como variável."""
    nomes = set(re.findall(r"[A-Za-z_]\w*", re.sub(r"\d+(\.\d+)?[eE][+-]?\d+", "0", expr)))
    soltos = sorted(nomes - FUNCS.keys() - CONSTS.keys())
    for n in soltos:
        if not (len(n) == 1 or n in GREGOS):
            raise ContaInvalida(f"não sei o que é '{n}'")
    return soltos


def avalia(expr: str, sp=None):
    """Caminha no ast. sp = módulo sympy → monta expressão simbólica com as variáveis."""
    if sp:
        consts = {"pi": sp.pi, "e": sp.E, "tau": 2 * sp.pi}
        funcs = {"sqrt": sp.sqrt, "cbrt": sp.cbrt, "sin": sp.sin, "cos": sp.cos, "tan": sp.tan,
                 "asin": sp.asin, "acos": sp.acos, "atan": sp.atan, "sinh": sp.sinh,
                 "cosh": sp.cosh, "tanh": sp.tanh, "log": sp.log, "exp": sp.exp,
                 "log10": lambda x: sp.log(x, 10), "log2": lambda x: sp.log(x, 2),
                 "abs": sp.Abs, "factorial": sp.factorial, "comb": sp.binomial}
        num = lambda v: sp.Integer(v) if isinstance(v, int) else sp.Rational(repr(v))
        simbolos = {v: sp.Symbol(v) for v in variaveis(expr)}
    else:
        consts, funcs, num, simbolos = CONSTS, FUNCS, (lambda v: v), {}

    def numero(x):
        return isinstance(x, (int, float)) or (sp is not None and getattr(x, "is_number", False))

    def no(n):
        if isinstance(n, ast.Expression):
            return no(n.body)
        if isinstance(n, ast.Constant) and type(n.value) in (int, float):
            return num(n.value)
        if isinstance(n, ast.Name) and n.id in consts:
            return consts[n.id]
        if isinstance(n, ast.Name) and n.id in simbolos:
            return simbolos[n.id]
        if isinstance(n, ast.UnaryOp) and isinstance(n.op, (ast.USub, ast.UAdd)):
            v = no(n.operand)
            return -v if isinstance(n.op, ast.USub) else v
        if isinstance(n, ast.BinOp) and type(n.op) in OPS:
            a, b = no(n.left), no(n.right)
            if (isinstance(n.op, ast.Pow) and numero(a) and numero(b)
                    and (abs(b) > 1000 or (abs(a) > 1e6 and abs(b) > 50))):
                raise ContaInvalida("potência grande demais")
            return OPS[type(n.op)](a, b)
        if (isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id in funcs
                and not n.keywords):
            args = [no(a) for a in n.args]
            nome = n.func.id
            if nome in ("factorial", "comb") and all(numero(a) for a in args):
                if not all(float(a).is_integer() and 0 <= a <= 1000 for a in args):
                    raise ContaInvalida(f"{nome} só de inteiro entre 0 e 1000")
                if not sp:
                    args = [int(a) for a in args]
                    return math.factorial(*args) if nome == "factorial" else math.comb(*args)
            return funcs[nome](*args)
        raise ContaInvalida("conta com coisa que não é número")

    try:
        return no(ast.parse(expr, mode="eval"))
    except (SyntaxError, TypeError, ZeroDivisionError, OverflowError, ValueError) as e:
        raise ContaInvalida(str(e)) from e


def formata(x) -> str:
    if isinstance(x, complex):
        raise ContaInvalida("deu número complexo")
    if isinstance(x, int):
        return str(x)
    if math.isinf(x) or math.isnan(x):
        raise ContaInvalida("não dá número")
    if x.is_integer() and abs(x) < 1e15:
        return str(int(x))
    return f"{x:.10g}".replace(".", ",")


def _sympy():
    try:
        import sympy
        return sympy
    except ImportError:
        raise ContaInvalida("conta com variável precisa do sympy (pip install --user sympy)")


def bonito(x) -> str:
    """Expressão do sympy pra ler numa linha: 5·x, x^2, √2, α, vírgula decimal."""
    s = str(x).replace("**", "^").replace("*", "·")
    s = re.sub(r"sqrt\(([^()]*)\)", r"√\1", s)
    s = re.sub(r"(?<=\d)\.(?=\d)", ",", s)
    for nome, letra in GREGOS.items():
        s = re.sub(rf"\b{nome}\b", letra, s)
    return s.replace("pi", "π").replace("I", "i")


def _aprox(sp, x) -> str:
    """'√2 ≈ 1,414' quando o valor exato não é um número redondo."""
    exato = bonito(x)
    if x.is_number and not x.is_Integer:
        try:
            valor = f"{float(x):.6g}".replace(".", ",")
        except TypeError:  # complexo: fica só o exato
            return exato
        if valor != exato:
            return f"{exato} ≈ {valor}"
    return exato


def _simbolica(esq: str, dir_: str | None) -> dict:
    sp = _sympy()
    a = avalia(esq, sp)
    if dir_ is None:
        r = sp.simplify(a)
        return {"titulo": "= " + _aprox(sp, r), "copia": sp.latex(r), "expr": esq}
    b = avalia(dir_, sp)
    livres = sorted((a - b).free_symbols, key=lambda s: (s.name != "x", s.name))
    if not livres:
        return {"titulo": "verdadeiro" if sp.simplify(a - b) == 0 else "falso",
                "copia": "", "expr": f"{esq} = {dir_}"}
    v = livres[0]  # resolve pro x se tiver, senão pra primeira letra
    sols = sp.solve(sp.Eq(a, b), v)
    reais = [s for s in sols if s.is_real is not False]
    sols = reais or sols
    if not sols:
        return {"titulo": f"sem solução pra {bonito(v)}", "copia": "", "expr": f"{esq} = {dir_}"}
    nome = bonito(v)
    return {"titulo": " ou ".join(f"{nome} = {_aprox(sp, s)}" for s in sols),
            "copia": ", ".join(f"{sp.latex(v)} = {sp.latex(s)}" for s in sols),
            "expr": f"{esq} = {dir_}"}


def conta(texto: str) -> dict:
    try:
        s = texto.strip().rstrip("=").strip()
        lados = re.split(r"(?<![<>!=])=(?!=)", s)
        if len(lados) > 2:
            raise ContaInvalida("mais de um =")
        esq = traduz(lados[0])
        dir_ = traduz(lados[1]) if len(lados) == 2 else None
        if dir_ is None and not variaveis(esq):
            valor = formata(avalia(esq))
            return {"ok": True, "titulo": "= " + valor, "valor": valor, "copia": valor, "expr": esq}
        if dir_ is not None:
            variaveis(dir_)
        r = _simbolica(esq, dir_)
        return {"ok": True, "valor": r["copia"], **r}
    except (ContaInvalida, RecursionError) as e:
        return {"ok": False, "erro": str(e)}
    except Exception as e:  # sympy pode reclamar de muita coisa; o launcher só esconde a linha
        return {"ok": False, "erro": f"{type(e).__name__}: {e}"}


if __name__ == "__main__":
    print(json.dumps(conta(" ".join(sys.argv[1:])), ensure_ascii=False))
