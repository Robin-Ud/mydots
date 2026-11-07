#!/bin/bash
# Testes dos comandos: cabeçalhos válidos + os scripts que dá pra rodar sem efeito colateral.
# Roda numa HOME falsa em /tmp; não toca na pasta real nem abre VS Code.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
falhas=0
ok()   { echo "  ok  $1"; }
erro() { echo "  ERRO $1"; falhas=$((falhas + 1)); }

echo "cabeçalhos (mesma regra do comandos.luau):"
python3 - "$DIR" <<'PY' || falhas=$((falhas + 1))
import os, re, sys
d = sys.argv[1]
ruim = 0
for arq in sorted(os.listdir(d)):
    p = os.path.join(d, arq)
    if os.path.isdir(p) or arq.startswith(".") or arq.endswith(".md") or "_test." in arq:
        continue
    desc, modo = "", "notificar"
    with open(p, encoding="utf-8") as f:
        linhas = f.read().split("\n")[:12]
    for l in linhas:
        if l.startswith("#") and not l.startswith("#!"):
            corpo = l[1:].strip()
            m = re.match(r"^(icone|modo):\s*(.*?)\s*$", corpo)
            if m and m[1] == "modo":
                modo = m[2]
            elif not m and not desc and corpo:
                desc = corpo
    probs = []
    if not os.access(p, os.X_OK): probs.append("sem chmod +x")
    if not desc: probs.append("sem descrição")
    if modo not in ("notificar", "fundo", "terminal"): probs.append(f"modo inválido '{modo}'")
    if probs:
        ruim += 1
        print(f"  ERRO {arq}: {', '.join(probs)}")
    else:
        print(f"  ok  {arq} [{modo}] {desc}")
sys.exit(1 if ruim else 0)
PY

echo "scripts:"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/home/.config/comandos" "$T/bin"
printf '#!/bin/sh\nexit 0\n' > "$T/bin/code"; chmod +x "$T/bin/code"   # VS Code de mentira
printf '#!/bin/sh\ncat >/dev/null\n' > "$T/bin/wl-copy"; chmod +x "$T/bin/wl-copy"
roda() { HOME="$T/home" PATH="$T/bin:$PATH" "$@"; }

out=$(roda "$DIR/ip.sh") && [[ $out == *"Local:"* && $out == *"Tailscale:"* ]] && ok "ip mostra local e tailscale" || erro "ip: $out"
roda "$DIR/novo.sh" 2>/dev/null && erro "novo sem nome devia falhar" || ok "novo sem nome falha"
roda "$DIR/novo.sh" 'Nome Ruim' 2>/dev/null && erro "novo aceitou nome com espaço" || ok "novo recusa nome ruim"
roda "$DIR/novo.sh" teste && [ -x "$T/home/.config/comandos/teste.sh" ] && ok "novo cria teste.sh executável" || erro "novo não criou"
out=$(roda "$T/home/.config/comandos/teste.sh" a b) && [ "$out" = "oi do teste: a b" ] && ok "molde roda e recebe args" || erro "molde: $out"
echo 'mudei' >> "$T/home/.config/comandos/teste.sh"
roda "$DIR/novo.sh" teste && grep -q mudei "$T/home/.config/comandos/teste.sh" && ok "novo não sobrescreve existente" || erro "novo sobrescreveu"
printf '#!/bin/sh\necho "$@" >> %s/notif\n' "$T" > "$T/bin/notify-send"; chmod +x "$T/bin/notify-send"
roda "$DIR/timer.sh" xyz && erro "timer aceitou tempo inválido" || { grep -q inválido "$T/notif" && ok "timer avisa tempo inválido" || erro "timer sem aviso"; }
roda "$DIR/timer.sh" 0.01 pronto && grep -q pronto "$T/notif" && ok "timer número = minutos, avisa no fim" || erro "timer não avisou"

echo "contas em LaTeX:"
python3 "$DIR/noctalia/comandos/contas_test.py" | grep -v "^  ok" || falhas=$((falhas + 1))

echo
[ "$falhas" -eq 0 ] && echo "tudo certo" || { echo "$falhas falha(s)"; exit 1; }
