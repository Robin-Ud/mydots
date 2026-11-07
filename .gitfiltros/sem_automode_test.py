"""Testes do sem_automode.py — rode: python3 .gitfiltros/sem_automode_test.py"""

import json
import os
import subprocess
import sys
import unittest

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from sem_automode import limpar  # noqa: E402

COM = {"model": "opus", "autoMode": {"environment": ["repo privado: x"]}, "tui": "fullscreen"}


class Limpar(unittest.TestCase):
    def test_tira_o_automode_e_mantem_o_resto_na_ordem(self):
        saida = limpar(json.dumps(COM, indent=2))
        self.assertNotIn("autoMode", saida)
        self.assertEqual(list(json.loads(saida)), ["model", "tui"])

    def test_sem_automode_passa_byte_a_byte(self):
        bruto = '{\n    "model": "opus"\n}'  # formatação diferente da do json.dumps
        self.assertEqual(limpar(bruto), bruto)

    def test_json_invalido_passa_intacto(self):
        bruto = '{"model": "opus",'
        self.assertEqual(limpar(bruto), bruto)

    def test_acento_sobrevive(self):
        saida = limpar(json.dumps({"autoMode": 1, "nota": "configuração"}, ensure_ascii=False))
        self.assertIn("configuração", saida)

    def test_como_o_git_chama_stdin_stdout(self):
        r = subprocess.run([sys.executable, os.path.join(AQUI, "sem_automode.py")],
                           input=json.dumps(COM).encode(), capture_output=True, check=True)
        self.assertNotIn(b"autoMode", r.stdout)


if __name__ == "__main__":
    unittest.main()
