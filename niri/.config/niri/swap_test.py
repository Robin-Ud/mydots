#!/usr/bin/env python3
"""Testes do swap.py: python3 swap_test.py"""

import unittest

from swap import neighbor, proportion


def win(wid, col, ws=1):
    return {"id": wid, "workspace_id": ws, "layout": {"pos_in_scrolling_layout": [col, 1]}}


class Proportion(unittest.TestCase):
    def test_meia_tela(self):
        # medido no monitor de 1920px: 2 colunas de 50% com gaps 2 + struts 4 dão 953px
        self.assertEqual(proportion(953, 1920), "50.00%")

    def test_sessenta(self):
        self.assertEqual(proportion(1144, 1920), "60.00%")

    def test_gaps_antigos(self):
        # config antiga (gaps 6, sem struts): 951px eram 50%
        self.assertEqual(proportion(951, 1920, gaps=6, struts=0), "50.00%")


class Neighbor(unittest.TestCase):
    def setUp(self):
        self.ws = [win(1, 1), win(2, 2), win(3, 3), win(9, 2, ws=2)]

    def test_esquerda(self):
        self.assertEqual(neighbor(self.ws, self.ws[1], "left")["id"], 1)

    def test_direita(self):
        self.assertEqual(neighbor(self.ws, self.ws[1], "right")["id"], 3)

    def test_borda_sem_vizinho(self):
        self.assertIsNone(neighbor(self.ws, self.ws[0], "left"))

    def test_ignora_outro_workspace(self):
        self.assertIsNone(neighbor(self.ws, self.ws[3], "right"))


if __name__ == "__main__":
    unittest.main()
