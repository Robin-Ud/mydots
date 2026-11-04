#!/usr/bin/env python3
"""Testes do solo.py: python3 solo_test.py"""

import unittest

from solo import PAIR_WIDTH, SOLO_WIDTH, apply_event, decide


def win(wid, ws=1, col=1, floating=False):
    return {"id": wid, "workspace_id": ws, "is_floating": floating,
            "layout": {"pos_in_scrolling_layout": None if floating else [col, 1]}}


def state(*ws):
    return {w["id"]: w for w in ws}


class Decide(unittest.TestCase):
    def test_sozinha_alarga(self):
        actions, widened = decide(state(win(1)), set())
        self.assertEqual(actions, [(1, SOLO_WIDTH)])
        self.assertEqual(widened, {1})

    def test_ja_alargada_nao_repete(self):
        actions, widened = decide(state(win(1)), {1})
        self.assertEqual(actions, [])
        self.assertEqual(widened, {1})

    def test_segunda_janela_volta_a_metade(self):
        actions, widened = decide(state(win(1, col=1), win(2, col=2)), {1})
        self.assertEqual(actions, [(1, PAIR_WIDTH)])
        self.assertEqual(widened, set())

    def test_nao_mexe_no_que_nao_alargou(self):
        actions, _ = decide(state(win(1, col=1), win(2, col=2)), set())
        self.assertEqual(actions, [])

    def test_empilhada_na_mesma_coluna_conta_como_uma(self):
        actions, widened = decide(state(win(1, col=1), win(2, col=1)), {1})
        self.assertEqual(actions, [])
        self.assertEqual(widened, {1, 2})

    def test_flutuante_nao_conta(self):
        actions, _ = decide(state(win(1), win(2, floating=True)), set())
        self.assertEqual(actions, [(1, SOLO_WIDTH)])

    def test_workspaces_independentes(self):
        actions, _ = decide(state(win(1, ws=1), win(2, ws=2)), set())
        self.assertEqual(sorted(actions), [(1, SOLO_WIDTH), (2, SOLO_WIDTH)])

    def test_fechou_uma_a_outra_alarga(self):
        windows = state(win(1, col=1), win(2, col=2))
        apply_event(windows, {"WindowClosed": {"id": 2}})
        actions, _ = decide(windows, set())
        self.assertEqual(actions, [(1, SOLO_WIDTH)])


class ApplyEvent(unittest.TestCase):
    def test_layout_muda_coluna(self):
        windows = state(win(1, col=1), win(2, col=2))
        changed = apply_event(windows, {"WindowLayoutsChanged": {"changes": [[2, {"pos_in_scrolling_layout": [1, 2]}]]}})
        self.assertTrue(changed)
        self.assertEqual(windows[2]["layout"]["pos_in_scrolling_layout"], [1, 2])

    def test_evento_irrelevante(self):
        self.assertFalse(apply_event({}, {"OverviewOpenedOrClosed": {"is_open": True}}))


if __name__ == "__main__":
    unittest.main()
