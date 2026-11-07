#!/usr/bin/env python3
"""Testes do telas.py: python3 telas_test.py"""

import unittest

from telas import plan


def ws(wid, output, active=False, focused=False):
    return {"id": wid, "output": output, "is_active": active, "is_focused": focused}


class Plan(unittest.TestCase):
    def test_troca_e_foco_vai_junto(self):
        acts = plan([ws(1, "eDP-1", True), ws(2, "eDP-1"), ws(3, "HDMI-A-1", True, True)])
        self.assertEqual(acts[0], {"MoveWorkspaceToMonitor": {"output": "HDMI-A-1", "reference": {"Id": 1}}})
        self.assertEqual(acts[1], {"MoveWorkspaceToMonitor": {"output": "eDP-1", "reference": {"Id": 3}}})
        self.assertEqual(acts[-1], {"FocusWorkspace": {"reference": {"Id": 3}}})

    def test_uma_tela_nao_faz_nada(self):
        self.assertIsNone(plan([ws(1, "eDP-1", True, True), ws(2, "eDP-1")]))

    def test_tres_telas_nao_faz_nada(self):
        self.assertIsNone(plan([ws(1, "a", True), ws(2, "b", True), ws(3, "c", True)]))


if __name__ == "__main__":
    unittest.main()
