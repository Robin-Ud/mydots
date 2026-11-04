# mydots

Meus dotfiles do Fedora com niri + Noctalia, iguais no note e no PC. Cada pasta é um pacote do
[GNU Stow](https://www.gnu.org/software/stow/): dentro dela fica a árvore como ela
aparece na home, e o `stow` cria os symlinks.

```bash
git clone https://github.com/Robin-Ud/mydots ~/.mydots
cd ~/.mydots
stow niri kitty nvim     # só os pacotes que quiser
stow -R niri             # refaz os links depois de criar arquivo novo no pacote
```

A edição é sempre aqui no repo, nunca em `~/.config` direto: o arquivo de lá é
só um link para cá.

## Pacotes

| Pacote | O que tem |
|---|---|
| `niri` | niri, o desktop (binds e jeito do Hyprland; detalhes abaixo) |
| `noctalia` | barra, launcher, notificações, tela de bloqueio e agente de senha (polkit) |
| `kitty` | terminal |
| `nvim` | `init.lua` com lazy.nvim e o `lazy-lock.json` |
| `bash` | `.bashrc` comentado; os scripts que ele chama ficam em `~/.config/bash/` (logo pokémon, `settempcom.sh`, grifos do Zotero) junto com os testes |
| `blesh` | config do [ble.sh](https://github.com/akinomyoga/ble.sh) (autossugestão e realce no bash) |
| `starship` | prompt |
| `fastfetch` | layout do fastfetch usado no logo pokémon do bash |
| `bk` | bookmarks de diretório no bash (`source ~/.config/bk/bk.sh`) |
| `rofi` / `rbw` | lançador e o `rofi-rbw` (senhas do Bitwarden) |
| `scripts` | executáveis em `~/.local/bin` (abaixo) |
| `claude` | config, comandos e skills do Claude Code |
| `sistema` | **não é pacote do stow**: arquivos de fora da home, instalados com `sudo install` (abaixo) |

## niri

O mesmo `config.kdl` no note (Intel) e no PC (NVIDIA). Máquina nova:

```bash
git clone https://github.com/Robin-Ud/mydots ~/.mydots
~/.mydots/SetNiri.sh --dry-run   # mostra o que vai fazer
~/.mydots/SetNiri.sh             # instala pacotes, driver NVIDIA se tiver, Noctalia, stow
```

- **Por máquina:** monitor, escala e mesa digitalizadora ficam em `local.kdl`
  (fora do git, `include` opcional no fim do `config.kdl`). Modelos: `local.note.kdl`
  e `local.pc.kdl`; o `SetNiri.sh` escolhe pela bateria.
- **NVIDIA:** driver do RPM Fusion (`akmod-nvidia`) e o perfil que limita a VRAM do
  niri (`GLVidHeapReuseRatio 0`, recomendação do wiki do niri).
- **Do Hyprland:** gaps 2/6, mesma curva de animação, opacidade das inativas,
  `app.py` (Alt+letra traz o app, Alt+Shift+letra vai até ele), `vol-janela.sh`
  (Super+volume), `tablet.py` (Alt+W), `hypridle.conf` com os mesmos tempos
  (só suspende se tiver bateria). Resize pela borda funciona porque **não** tem
  `prefer-no-csd`; Super+botão direito redimensiona qualquer janela.
- **Sem master:** o niri só tem colunas. `swap.py` troca com a coluna do lado
  levando a largura junto com o lado, `solo.py` deixa janela sozinha em 100%,
  `scratch.py` é o scratchpad.
- Testes: `python3 <script>_test.py` em `niri/.config/niri` e `bash SetNiri_test.sh`.

## Hyprland, sway e companhia (arquivados)

O Hyprland (com waybar, wofi, hyprpaper, `show-keybinds` e os 4 `.conf` de layout),
o sway, o foot e o swaylock saíram do repo em nov/2026. O último estado está na tag
`hyprland-final`:

```bash
git checkout hyprland-final -- hypr waybar   # traz de volta só o que quiser
```

## Scripts (`scripts/.local/bin`)

- `att_diaria.sh`: atualiza o sistema (dnf) no boot, no máximo uma vez por dia.
- `tcd`: compila e roda (C, Python, shell) pelo nome do arquivo.

## Sistema (`sistema/`)

Ficam fora do stow porque o root executa: um symlink apontando pra home deixaria
um arquivo meu rodar como root.

- `touchpad-resume`: recarrega o driver do touchpad (`i2c_hid_acpi`) depois de
  toda suspensão, porque às vezes ele volta travado.
  `sudo install -m755 -o root -g root sistema/touchpad-resume /etc/systemd/system-sleep/`

Os caminhos absolutos (`/home/rud/...`) são da minha máquina: troque pelos seus.
