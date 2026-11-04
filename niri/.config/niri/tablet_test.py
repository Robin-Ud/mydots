#!/usr/bin/env python3
"""Testes do tablet.py: python3 tablet_test.py"""

import unittest

from tablet import current, following, render


class Ciclo(unittest.TestCase):
    def test_sem_arquivo_e_o_note(self):
        self.assertEqual(current(None), "eDP-1")

    def test_volta_ao_comeco(self):
        self.assertEqual([following(t) for t in ("eDP-1", "HDMI-A-1", "ambos")],
                         ["HDMI-A-1", "ambos", "eDP-1"])

    def test_tela_desconhecida_vai_pro_note(self):
        self.assertEqual(following("DP-3"), "eDP-1")

    def test_ida_e_volta_pelo_arquivo(self):
        for t in ("eDP-1", "HDMI-A-1", "ambos"):
            self.assertEqual(current(render(t)), t)

    def test_ambos_e_secao_vazia(self):
        self.assertNotIn("map-to-output", render("ambos"))


if __name__ == "__main__":
    unittest.main()
