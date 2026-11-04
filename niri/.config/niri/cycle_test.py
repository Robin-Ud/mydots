#!/usr/bin/env python3
"""Testes do cycle.py: python3 cycle_test.py"""

import unittest

from cycle import next_window


def win(wid, col, row=1, ws=1):
    return {"id": wid, "workspace_id": ws, "layout": {"pos_in_scrolling_layout": [col, row]}}


def floating(wid, ws=1):
    return {"id": wid, "workspace_id": ws, "layout": {"pos_in_scrolling_layout": None}}


class NextWindow(unittest.TestCase):
    def setUp(self):
        # coluna 1: janela 1; coluna 2: pilha 2 (em cima) e 3; coluna 3: janela 4
        # (fora de ordem de propósito, como o niri devolve)
        self.ws = [win(4, 3), win(3, 2, 2), win(1, 1), win(2, 2, 1), win(9, 1, ws=2)]
        self.by_id = {w["id"]: w for w in self.ws}

    def go(self, wid, step=1):
        return next_window(self.ws, self.by_id[wid], step)["id"]

    def test_entra_na_pilha_pelo_topo(self):
        self.assertEqual(self.go(1), 2)

    def test_desce_na_pilha(self):
        self.assertEqual(self.go(2), 3)

    def test_sai_da_pilha_pra_proxima_coluna(self):
        self.assertEqual(self.go(3), 4)

    def test_volta_pro_comeco(self):
        self.assertEqual(self.go(4), 1)

    def test_prev_volta_pro_fim(self):
        self.assertEqual(self.go(1, -1), 4)

    def test_prev_sobe_na_pilha(self):
        self.assertEqual(self.go(3, -1), 2)

    def test_ignora_outro_workspace(self):
        self.assertEqual(self.go(9), 9)

    def test_flutuante_comeca_pela_primeira(self):
        self.ws.append(floating(5))
        self.assertEqual(next_window(self.ws, self.ws[-1], 1)["id"], 1)

    def test_nada_focado(self):
        self.assertIsNone(next_window(self.ws, None, 1))


if __name__ == "__main__":
    unittest.main()
