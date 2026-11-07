# CLAUDE.md

Dotfiles do Matheus, um pacote do GNU Stow por programa (ver README). Público
(github.com/Robin-Ud/mydots); o mesmo repo serve o note e o PC.

## Regras
- Nunca editar `~/.config/...` direto: o arquivo de verdade mora aqui. Antes de
  apagar ou trocar algo em `~/.config/X`, `ls -ld` (pode ser symlink da pasta inteira).
- Commits no padrão do `~/.claude/CLAUDE.md`. Escopo = nome do pacote do stow
  (`niri`, `noctalia`, `kitty`, `bash`, `vscode`, `vim`, `claude`, `comandos`,
  `mimeapps`, `scripts`, `rbw`, `sistema`, `blesh`, `bk`, `starship`...), mais
  `wallpaper` e `readme`. Mexeu em vários pacotes pra uma coisa só → sem escopo.
- E-mail do repo é o noreply do GitHub (`git config user.email`); o global ainda é
  o gmail, então confira em clone novo.
- Público: nada de dado pessoal (nome de repo privado, nº USP, senha). O
  `autoMode` do Claude Code fica em `~/.claude/settings.local.json`, fora daqui.
- Testes: `python3 <script>_test.py` em `niri/.config/niri`, `bash SetNiri_test.sh`,
  `bash comandos/.config/comandos/comandos_test.sh`, `bash bk/.config/bk/bk_test.sh`; config do niri com
  `niri validate -c niri/.config/niri/config.kdl`.
