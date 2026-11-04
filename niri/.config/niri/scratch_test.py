#!/usr/bin/env python3
"""Testes do scratch.py: python3 scratch_test.py"""

import unittest

from scratch import end_idx, toggle_plan


def ws(wid, idx, output="eDP-1"):
    return {"id": wid, "idx": idx, "output": output}


class EndIdx(unittest.TestCase):
    def test_ultimo_do_monitor(self):
        workspaces = [ws(1, 1), ws(2, 2), ws(3, 3), ws(9, 5, output="HDMI-A-1")]
        self.assertEqual(end_idx(workspaces, "eDP-1"), 3)


class TogglePlan(unittest.TestCase):
    def setUp(self):
        # 1 e 2 normais, 3 é o scratchpad, 4 é o vazio do fim
        self.workspaces = [ws(10, 1), ws(11, 2), ws(12, 3), ws(13, 4)]

    def test_entra(self):
        plan = toggle_plan({"ws": 12}, self.workspaces, self.workspaces[0])
        self.assertEqual(plan, ("go", 3))

    def test_volta_pra_onde_estava(self):
        plan = toggle_plan({"ws": 12, "back": 11}, self.workspaces, self.workspaces[2])
        self.assertEqual(plan, ("back", 2))

    def test_volta_pro_1_se_o_de_origem_sumiu(self):
        plan = toggle_plan({"ws": 12, "back": 99}, self.workspaces, self.workspaces[2])
        self.assertEqual(plan, ("back", 1))

    def test_cria_no_fim_sem_estado(self):
        self.assertEqual(toggle_plan({}, self.workspaces, self.workspaces[0]), ("new", 4))

    def test_cria_no_fim_se_o_niri_apagou(self):
        # scratchpad vazio que você deixou: o niri remove e o id fica velho
        plan = toggle_plan({"ws": 99}, self.workspaces, self.workspaces[0])
        self.assertEqual(plan, ("new", 4))

    def test_outro_monitor_cria_neste(self):
        workspaces = self.workspaces + [ws(20, 1, output="HDMI-A-1")]
        plan = toggle_plan({"ws": 20}, workspaces, self.workspaces[0])
        self.assertEqual(plan, ("new", 4))


if __name__ == "__main__":
    unittest.main()
