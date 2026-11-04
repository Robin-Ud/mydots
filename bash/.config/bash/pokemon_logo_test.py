"""Testes do pokemon_logo.py — rode: python3 -m unittest pokemon_logo_test"""
import unittest
import zlib

import pokemon_logo as p

V, A = (255, 0, 0), (0, 0, 255)
R = "\x1b[0m"


class TestConversao(unittest.TestCase):
    def test_meio_blocos(self):
        # ▀ vermelho sobre azul | ▄ vermelho sem fundo | espaço transparente
        arte = f"\x1b[38;2;255;0;0m\x1b[48;2;0;0;255m▀{R}\x1b[38;2;255;0;0m▄{R} \n"
        self.assertEqual(p.ansi_para_pixels(arte), [[V, None], [A, V]])

    def test_recorta_borda_transparente(self):
        img = [[None, None, None], [None, V, None], [None, None, None]]
        self.assertEqual(p.recortar(img), [[V]])

    def test_png_valido_e_ampliado(self):
        dados = p.png([[V, None]], 3)
        self.assertTrue(dados.startswith(b"\x89PNG"))
        w, h = int.from_bytes(dados[16:20], "big"), int.from_bytes(dados[20:24], "big")
        self.assertEqual((w, h), (6, 3))

    def test_colunas_mantem_proporcao(self):
        # sprite quadrado, 10 linhas de 20 px = 200 px de altura -> 200/10 = 20 colunas
        self.assertEqual(p.colunas_do_logo([[V] * 40] * 40, 10, (10, 20)), 20)


if __name__ == "__main__":
    unittest.main()
