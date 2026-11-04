#!/usr/bin/env python3
"""Testa o vigia-anki.py contra um AnkiConnect falso (não toca o Anki real)."""
import importlib.util
import io
import json
import os
import threading
import time
import unittest
from contextlib import redirect_stdout
from http.server import BaseHTTPRequestHandler, HTTPServer

AQUI = os.path.dirname(os.path.abspath(__file__))


class Falso:
    """Estado do Anki de mentira: card na tela, revlog e bandeiras."""
    def __init__(self):
        self.tela = None        # (cid, deck) ou None
        self.revlog = {}        # cid -> [ {id, ease} ]
        self.flags = {1: [], 2: []}

    def responder(self, cid, ease):
        rid = int(time.time() * 1000) + len(sum(self.revlog.values(), []))
        self.revlog.setdefault(cid, []).append({"id": rid, "ease": ease})

    def acao(self, nome, p):
        if nome == "guiCurrentCard":
            if self.tela is None:
                return None, "Gui review is not currently active."
            return {"cardId": self.tela[0], "deckName": self.tela[1],
                    "answer": "RESPOSTA SECRETA"}, None
        if nome == "getReviewsOfCards":
            return {str(c): self.revlog.get(c, []) for c in p["cards"]}, None
        if nome == "findCards":
            return self.flags[int(p["query"].split(":")[1])], None
        return None, "ação desconhecida"


def servidor(falso):
    class H(BaseHTTPRequestHandler):
        def do_POST(self):
            req = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            res, err = falso.acao(req["action"], req.get("params", {}))
            corpo = json.dumps({"result": res, "error": err}).encode()
            self.send_response(200)
            self.end_headers()
            self.wfile.write(corpo)

        def log_message(self, *a):
            pass
    srv = HTTPServer(("127.0.0.1", 0), H)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


def carregar(url):
    os.environ.update(ANKICONNECT=url, VIGIA_FIM="0.2")
    spec = importlib.util.spec_from_file_location("vigia", os.path.join(AQUI, "vigia-anki.py"))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


class Teste(unittest.TestCase):
    def setUp(self):
        self.f = Falso()
        self.srv = servidor(self.f)
        self.m = carregar(f"http://127.0.0.1:{self.srv.server_port}")
        self.f.flags[1] = [999]  # bandeira antiga: não pode virar evento
        self.v = self.m.Vigia()
        self.v.t0 -= 1

    def tearDown(self):
        self.srv.shutdown()
        self.srv.server_close()

    def passo(self):
        out = io.StringIO()
        with redirect_stdout(out):
            self.v.passo()
        return out.getvalue().splitlines()

    def test_sessao_completa(self):
        self.assertEqual(self.passo(), [])                       # sem revisor
        self.f.tela = (10, "Botânica")
        self.assertEqual(self.passo(), ["inicio: Botânica"])
        self.f.responder(10, 3)                                   # acertou
        self.f.tela = (11, "Botânica")
        self.assertEqual(self.passo(), [])
        self.f.responder(11, 1)                                   # errou
        self.f.tela = (12, "Botânica")
        self.assertEqual(self.passo(), ["errou: card=11 deck=Botânica vezes=1"])
        self.f.responder(12, 4)
        self.f.tela = (11, "Botânica")                            # volta o errado
        self.assertEqual(self.passo(), [])
        self.f.responder(11, 1)                                   # errou de novo
        self.f.tela = None                                        # parabéns
        self.assertEqual(self.passo(), ["errou: card=11 deck=Botânica vezes=2"])
        time.sleep(0.3)
        fim = self.passo()
        self.assertEqual(len(fim), 1)
        self.assertTrue(fim[0].startswith("fim: 4 revisões"), fim)
        self.assertIn("de novo 2, bom 1, fácil 1", fim[0])
        self.assertIn("erros: 11(2x)", fim[0])

    def test_mesmo_card_seguido(self):
        self.f.tela = (20, "X")
        self.passo()
        self.f.responder(20, 1)                                   # card não troca
        self.assertEqual(self.passo(), ["errou: card=20 deck=X vezes=1"])
        self.assertEqual(self.passo(), [])                        # não repete

    def test_nunca_vaza_resposta(self):
        self.f.tela = (30, "X")
        self.assertNotIn("SECRETA", "".join(self.passo()))

    def test_bandeiras(self):
        self.assertEqual(self.passo(), [])                        # base: 999 ignorado
        self.f.flags[1] = [999, 40]
        self.f.flags[2] = [41]
        self.assertEqual(self.passo(), ["bandeira vermelha: card=40",
                                        "bandeira laranja: card=41"])
        self.assertEqual(self.passo(), [])
        self.f.flags[2] = []
        self.passo()
        self.f.flags[2] = [41]                                    # pôs de novo
        self.assertEqual(self.passo(), ["bandeira laranja: card=41"])

    def test_anki_fechado(self):
        self.f.tela = (50, "X")
        self.passo()
        self.f.responder(50, 3)
        self.passo()
        self.srv.shutdown()
        self.srv.server_close()
        self.m.POLL = 0
        out = io.StringIO()
        with redirect_stdout(out):
            orig = self.m.time.sleep
            self.m.time.sleep = lambda s: (_ for _ in ()).throw(KeyboardInterrupt)
            try:
                self.v.rodar()
            except KeyboardInterrupt:
                pass
            finally:
                self.m.time.sleep = orig
        linhas = out.getvalue().splitlines()
        self.assertEqual(len(linhas), 2, linhas)
        self.assertTrue(linhas[0].startswith("fim: 1 revisão em"), linhas)
        self.assertEqual(linhas[1], "anki: fechado")
        self.srv = servidor(self.f)  # pro tearDown


if __name__ == "__main__":
    unittest.main(verbosity=2)
