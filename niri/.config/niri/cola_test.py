#!/usr/bin/env python3
"""Testes do cola.py: python3 cola_test.py"""

import os
import unittest

from cola import CONFIG, DIARIO, agrupar, bate, colunas, comando, ler_binds, secao, socorro_cmd, teclas, texto_busca

EXEMPLO = """
recent-windows {
    binds {
        Mod+Tab         { next-window; }
        Mod+grave       { next-window     filter="app-id"; }
    }
}

binds {
    Mod+Slash hotkey-overlay-title="Cola" { spawn "cola.py"; }

    // Foco (vim + setas)
    Mod+H hotkey-overlay-title="Foco: esquerda (ou ←)" { focus-column-left; }
    Mod+Left hotkey-overlay-title=null { focus-column-left; }
    // comentário colado não muda a seção
    Mod+Print hotkey-overlay-title="Print \\"nativo\\"" { screenshot; }

    // Prints: área de transferência
    Shift+Print hotkey-overlay-title="Print de área" { spawn-sh "grim -g \\"$(slurp)\\" - | wl-copy"; }
}
"""


class Ler(unittest.TestCase):
    def setUp(self):
        self.l = ler_binds(EXEMPLO)

    def test_secoes_e_ordem(self):
        self.assertEqual([x["secao"] for x in self.l],
                         ["Trocar de janela", "Trocar de janela", "Geral", "Foco", "Foco", "Prints"])

    def test_null_vira_variante(self):
        foco = self.l[3]
        self.assertEqual((foco["bind"], foco["variantes"]), ("Mod+H", ["Mod+Left"]))

    def test_aspas_escapadas_no_titulo(self):
        self.assertEqual(self.l[4]["titulo"], 'Print "nativo"')

    def test_sem_titulo_usa_acao(self):
        self.assertIn("Tab", self.l[0]["titulo"])
        self.assertEqual(self.l[1]["titulo"], "Janela usada por último, só do mesmo app")


class Formato(unittest.TestCase):
    def test_teclas(self):
        self.assertEqual(teclas("Mod+Shift+Slash"), ["Super", "Shift", "/"])
        self.assertEqual(teclas("Mod+Ctrl+Left"), ["Super", "Ctrl", "←"])

    def test_secao(self):
        self.assertEqual(secao("// Foco (vim + setas)"), "Foco")
        self.assertEqual(secao("// Colunas (o \"master\" do Hyprland): ..."), "Colunas")
        self.assertEqual(secao("// Mesa digitalizadora: notebook → monitor"), "Mesa digitalizadora")

    def test_busca_sem_acento_e_por_tecla(self):
        alvo = texto_busca({"secao": "Prints", "bind": "Shift+Print",
                            "titulo": "Print de área", "variantes": []})
        self.assertTrue(bate("AREA", alvo))
        self.assertTrue(bate("shift print", alvo))
        self.assertFalse(bate("volume", alvo))
        self.assertTrue(bate("", alvo))


class Notas(unittest.TestCase):
    def test_nota_da_secao_e_do_bind(self):
        l = ler_binds(EXEMPLO)
        self.assertEqual(l[3]["nota_secao"], "Foco (vim + setas)")
        self.assertEqual(l[3]["nota"], "")
        self.assertEqual(l[4]["nota"], "comentário colado não muda a seção")


class Colunas(unittest.TestCase):
    def test_nao_quebra_secao_e_equilibra(self):
        grupos = [(str(i), [0] * n) for i, n in enumerate([6, 2, 8, 3, 5, 4, 7, 2])]
        cols = colunas(grupos, 3)
        self.assertEqual(len(cols), 3)
        self.assertEqual([g for c in cols for g in c], grupos)
        alturas = [sum(len(ls) + 2 for _, ls in c) for c in cols]
        self.assertEqual(max(alturas), 22)  # o melhor corte possível dessas alturas

    def test_poucas_secoes(self):
        self.assertEqual(len(colunas([("a", [0])], 3)), 1)

    def test_agrupar(self):
        self.assertEqual([n for n, _ in agrupar(ler_binds(EXEMPLO))],
                         ["Trocar de janela", "Geral", "Foco", "Prints"])


class Comando(unittest.TestCase):
    def test_opcao_e_posicional(self):
        self.assertEqual(comando("move-column-to-workspace", " 9 focus=false; "),
                         ["niri", "msg", "action", "move-column-to-workspace", "--focus", "false", "--", "9"])

    def test_negativo_vai_depois_do_traco_traco(self):
        self.assertEqual(comando("set-column-width", ' "-5%"; ')[-2:], ["--", "-5%"])

    def test_sem_argumento(self):
        self.assertEqual(comando("close-window", "; "), ["niri", "msg", "action", "close-window"])

    def test_aspas_escapadas(self):
        self.assertEqual(comando("spawn-sh", r' "grim -g \"$(slurp)\" - | wl-copy"; ')[-1],
                         'grim -g "$(slurp)" - | wl-copy')

    def test_so_teclado(self):
        self.assertIsNone(comando("next-window", ' filter="app-id"; '))

    def test_bind_do_exemplo_tem_cmd(self):
        self.assertEqual(ler_binds(EXEMPLO)[4]["cmd"], ["niri", "msg", "action", "screenshot"])


class Socorro(unittest.TestCase):
    def test_guia_seguro(self):
        cmd = socorro_cmd()
        self.assertEqual(cmd[cmd.index("--permission-mode") + 1], "manual")
        self.assertIn("Write", cmd[cmd.index("--disallowedTools") + 1])
        prompt = cmd[cmd.index("--append-system-prompt") + 1]
        self.assertIn(CONFIG, prompt)
        self.assertNotIn("ATALHOS_CONFIG", prompt)
        # último flag antes do prompt inicial não pode ser variádico (engoliria o "Oi")
        self.assertEqual(cmd[-3], "--append-system-prompt")


class ConfigDeVerdade(unittest.TestCase):
    """DIARIO é escrito à mão: toda tecla dele tem que existir no config.kdl."""

    def test_diario_existe_no_config(self):
        if not os.path.exists(CONFIG):
            self.skipTest("sem config.kdl")
        texto = open(CONFIG, encoding="utf-8").read()
        todos = {l["bind"] for l in ler_binds(texto)}
        faltando = [b for b in DIARIO if b not in todos]
        self.assertEqual(faltando, [])


if __name__ == "__main__":
    unittest.main()
