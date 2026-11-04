#!/usr/bin/env python3
"""Testes do app.py: python3 app_test.py"""

import os
import tempfile
import unittest

from app import find, plan, recently_launched


def win(wid, app_id, ws, secs=0):
    return {"id": wid, "app_id": app_id, "workspace_id": ws,
            "focus_timestamp": {"secs": secs, "nanos": 0}}


def ws(wid, idx, output, focused=False):
    return {"id": wid, "idx": idx, "output": output, "is_focused": focused}


class Find(unittest.TestCase):
    def test_pega_a_usada_por_ultimo(self):
        ws_ = [win(1, "kitty", 1, secs=5), win(2, "kitty", 2, secs=9)]
        self.assertEqual(find(ws_, "kitty")["id"], 2)

    def test_exato_antes_de_maiusculas(self):
        ws_ = [win(1, "Anki", 1, secs=9), win(2, "net.ankiweb.Anki", 1, secs=1)]
        self.assertEqual(find(ws_, "net.ankiweb.Anki")["id"], 2)

    def test_ignora_maiusculas_se_nao_tem_exato(self):
        self.assertEqual(find([win(7, "QGIS", 1)], "qgis")["id"], 7)

    def test_nao_achou(self):
        self.assertIsNone(find([win(1, "kitty", 1)], "org.zotero.Zotero"))

    def test_app_id_nulo(self):
        self.assertIsNone(find([{"id": 1, "app_id": None, "workspace_id": 1}], "x"))


class Plan(unittest.TestCase):
    def setUp(self):
        self.spaces = [ws(1, 1, "eDP-1", focused=True), ws(3, 2, "eDP-1"),
                       ws(5, 1, "HDMI-A-1")]

    def test_sem_janela_abre(self):
        self.assertIsNone(plan("here", None, self.spaces))

    def test_goto_so_foca(self):
        self.assertEqual(plan("goto", win(4, "x", 3), self.spaces),
                         [["focus-window", "--id", "4"]])

    def test_here_ja_esta_aqui(self):
        self.assertEqual(plan("here", win(4, "x", 1), self.spaces),
                         [["focus-window", "--id", "4"]])

    def test_here_mesmo_monitor(self):
        self.assertEqual(plan("here", win(4, "x", 3), self.spaces), [
            ["move-window-to-workspace", "--window-id", "4", "--focus", "false", "1"],
            ["focus-window", "--id", "4"]])

    def test_here_outro_monitor(self):
        self.assertEqual(plan("here", win(4, "x", 5), self.spaces), [
            ["move-window-to-monitor", "--id", "4", "eDP-1"],
            ["focus-window", "--id", "4"]])


class Debounce(unittest.TestCase):
    def test_trava(self):
        with tempfile.TemporaryDirectory() as d:
            stamp = os.path.join(d, "s")
            self.assertFalse(recently_launched(stamp, 100.0))
            open(stamp, "w").close()
            os.utime(stamp, (100, 100))
            self.assertTrue(recently_launched(stamp, 105.0))
            self.assertFalse(recently_launched(stamp, 111.0))


if __name__ == "__main__":
    unittest.main()
