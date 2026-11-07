#!/usr/bin/env python3
"""Testes do aba.py: python3 aba_test.py"""

import unittest

from aba import RUNTIME, socket_for


class SocketFor(unittest.TestCase):
    def test_kitty_vira_socket_do_pid(self):
        self.assertEqual(socket_for({"app_id": "kitty", "pid": 42}), f"{RUNTIME}/kitty-42")

    def test_outro_app_nao(self):
        self.assertIsNone(socket_for({"app_id": "firefox", "pid": 42}))

    def test_sem_janela_nao(self):
        self.assertIsNone(socket_for(None))

    def test_sem_pid_nao(self):
        self.assertIsNone(socket_for({"app_id": "kitty"}))


if __name__ == "__main__":
    unittest.main()
