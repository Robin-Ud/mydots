#!/usr/bin/env python3
"""vigia-anki.py — gatilho do Monitor quando o tutor acompanha o Anki.

Consulta o AnkiConnect a cada POLL segundos e imprime uma linha por evento que
merece comentário. Acerto não imprime nada, pra não acordar o Claude à toa.

    inicio: <baralho>                        começou a revisar
    errou: card=<id> deck=<baralho> vezes=<n>  apertou "De novo" (n = nesta sessão)
    bandeira vermelha: card=<id>             Ctrl+1 = card com problema
    bandeira laranja: card=<id>              Ctrl+2 = me explica
    fim: <resumo>                            FIM_APOS s sem revisor ativo
    anki: fechado                            AnkiConnect parou de responder

Ele só avisa DEPOIS do botão: o guiCurrentCard já traz a resposta com o card
fechado, mas esta vigia não imprime nada sobre o card que está na tela.
Só lê o Anki, nunca escreve. Puro Python, zero deps.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request
from collections import Counter

URL = os.environ.get("ANKICONNECT", "http://127.0.0.1:8765")
POLL = float(os.environ.get("VIGIA_POLL", "1.5"))
FIM_APOS = float(os.environ.get("VIGIA_FIM", "90"))
BANDEIRAS = {1: "vermelha", 2: "laranja"}
BOTOES = {1: "de novo", 2: "difícil", 3: "bom", 4: "fácil"}


class Fechado(Exception):
    """AnkiConnect não respondeu (Anki fechado ou travado)."""


def chamar(acao, **params):
    """Uma ação do AnkiConnect; devolve None se ele respondeu com erro."""
    corpo = json.dumps({"action": acao, "version": 6, "params": params}).encode()
    try:
        with urllib.request.urlopen(URL, corpo, timeout=3) as r:
            resp = json.load(r)
    except (urllib.error.URLError, OSError, ValueError) as e:
        raise Fechado from e
    if resp.get("error"):
        return None  # ex.: "Gui review is not currently active."
    return resp.get("result")


def emitir(linha):
    print(linha, flush=True)


class Vigia:
    def __init__(self):
        self.t0 = int(time.time() * 1000)  # revisão com id (ms) antes disso é passado
        self.contadas = set()               # ids de revisão já processados
        self.deck_de = {}                   # card -> baralho (visto na tela)
        self.ultimo = None                  # último card visto na tela
        self.sessao = None
        self.sem_revisor_desde = None
        self.bandeiras = None               # {flag: set(cards)}; None = sem base ainda
        self.vivo = None

    # --- sessão -----------------------------------------------------------
    def abrir_sessao(self, deck):
        self.sessao = {"inicio": time.time(), "deck": deck,
                       "botoes": Counter(), "erros": Counter()}
        emitir(f"inicio: {deck}")

    def fechar_sessao(self):
        s, self.sessao = self.sessao, None
        if s is None:
            return
        n = sum(s["botoes"].values())
        if n == 0:
            return  # abriu o baralho e saiu sem responder nada
        minutos = max(1, round((time.time() - s["inicio"] - FIM_APOS) / 60))
        botoes = ", ".join(f"{BOTOES[b]} {s['botoes'][b]}"
                           for b in sorted(s["botoes"]) if b in BOTOES)
        erros = ",".join(f"{c}" + (f"({k}x)" if k > 1 else "")
                         for c, k in s["erros"].most_common()) or "nenhum"
        emitir(f"fim: {n} {'revisão' if n == 1 else 'revisões'} em ~{minutos} min ({botoes}); erros: {erros}")

    # --- um ciclo ---------------------------------------------------------
    def passo(self):
        atual = chamar("guiCurrentCard")
        self.vivo = True
        cid = atual["cardId"] if atual else None
        agora = time.time()

        if cid is not None:
            self.deck_de[cid] = atual.get("deckName", "?")
            self.sem_revisor_desde = None
            if self.sessao is None:
                self.abrir_sessao(self.deck_de[cid])
        elif self.sessao is not None:
            self.sem_revisor_desde = self.sem_revisor_desde or agora

        # revisões novas do card na tela e do anterior (o anterior é o que
        # acabou de ser respondido quando a tela troca de card)
        checar = sorted({c for c in (cid, self.ultimo) if c is not None})
        if checar:
            revs = chamar("getReviewsOfCards", cards=checar) or {}
            novas = [(r["id"], int(c), r) for c, lista in revs.items() for r in lista
                     if r["id"] > self.t0 and r["id"] not in self.contadas]
            for rid, c, r in sorted(novas):
                self.contadas.add(rid)
                self.registrar(c, r["ease"])
        if cid is not None:
            self.ultimo = cid

        self.olhar_bandeiras()

        if self.sem_revisor_desde and agora - self.sem_revisor_desde >= FIM_APOS:
            self.fechar_sessao()
            self.sem_revisor_desde = None

    def registrar(self, card, botao):
        if self.sessao is None:  # respondeu antes de vermos a tela (poll perdido)
            self.abrir_sessao(self.deck_de.get(card, "?"))
        self.sessao["botoes"][botao] += 1
        if botao == 1:
            self.sessao["erros"][card] += 1
            emitir(f"errou: card={card} deck={self.deck_de.get(card, '?')} "
                   f"vezes={self.sessao['erros'][card]}")

    def olhar_bandeiras(self):
        agora = {f: set(chamar("findCards", query=f"flag:{f}") or []) for f in BANDEIRAS}
        if self.bandeiras is None:  # bandeira que já existia não é pedido novo
            self.bandeiras = agora
            return
        for f, cards in agora.items():
            for c in sorted(cards - self.bandeiras[f]):
                emitir(f"bandeira {BANDEIRAS[f]}: card={c}")
        self.bandeiras = agora  # tirou e pôs de novo = pedido novo

    # --- laço -------------------------------------------------------------
    def rodar(self):
        while True:
            try:
                self.passo()
            except Fechado:
                if self.vivo is not False:
                    self.fechar_sessao()
                    emitir("anki: fechado" if self.vivo else "anki: fechado (esperando abrir)")
                self.vivo = False
                self.ultimo = None
                self.bandeiras = None  # rebase ao reabrir
                time.sleep(max(POLL, 5))
                continue
            time.sleep(POLL)


if __name__ == "__main__":
    try:
        Vigia().rodar()
    except (KeyboardInterrupt, BrokenPipeError):
        sys.exit(0)
