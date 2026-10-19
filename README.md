# mydots

Meus dotfiles do Fedora com Hyprland. Cada pasta é um pacote do
[GNU Stow](https://www.gnu.org/software/stow/): dentro dela fica a árvore como ela
aparece na home, e o `stow` cria os symlinks.

```bash
git clone https://github.com/Robin-Ud/mydots ~/.mydots
cd ~/.mydots
stow hypr kitty nvim     # só os pacotes que quiser
stow -R hypr             # refaz os links depois de criar arquivo novo no pacote
```

A edição é sempre aqui no repo, nunca em `~/.config` direto: o arquivo de lá é
só um link para cá.

## Pacotes

| Pacote | O que tem |
|---|---|
| `hypr` | Hyprland, hypridle, hyprpaper e scripts de janela |
| `waybar` | barra e estilo |
| `kitty` / `foot` | terminais (o kitty é o principal) |
| `nvim` | `init.lua` com lazy.nvim e o `lazy-lock.json` |
| `bash` | `.bashrc` comentado e um teste dele (`bashrc_test.sh`) |
| `blesh` | config do [ble.sh](https://github.com/akinomyoga/ble.sh) (autossugestão e realce no bash) |
| `starship` | prompt |
| `bk` | bookmarks de diretório no bash (`source ~/.config/bk/bk.sh`) |
| `rofi` / `wofi` | lançadores |
| `sway` | config do sway, de reserva |
| `scripts` | executáveis em `~/.local/bin` (abaixo) |
| `claude` | config, comandos e skills do Claude Code |

## Hyprland

- **Um `.conf` por layout:** `hyprland-{master,dwindle,scrolling,monocle}.conf`.
  Os binds de cada layout ficam no topo e o resto é igual em todos. Para trocar, copie o
  layout escolhido por cima do `hyprland.conf`.
- **`app-here.sh` / `app-goto.sh`:** um bind por programa (Obsidian, Anki, Zotero,
  Firefox). Se a janela já existe, o `app-here` traz ela para o workspace atual e o
  `app-goto` vai até ela. Se não existe, os dois abrem o programa.
- **Binds medidos:** quase todo bind passa pelo `track_bind.sh` do
  [UsageTracker](https://github.com/Robin-Ud/UsageTracker), que conta o uso de cada
  atalho para eu saber quais valem a pena.
- **`tablet-toggle.sh`:** a mesa digitalizadora alterna entre a tela do note, o
  monitor externo e as duas.

## Scripts (`scripts/.local/bin`)

- `att_diaria.sh`: atualiza o sistema (dnf) no boot, no máximo uma vez por dia.
- `show-keybinds`: cola dos binds do Hyprland no rofi.
- `tcd`: compila e roda (C, Python, shell) pelo nome do arquivo.
- `workspace-wallpaper`: troca o wallpaper ao mudar de workspace.
- `audio-sink-switcher`: escolhe a saída de som num menu do wofi.
- `dji-thumbs`: miniatura de vídeo DJI (HEVC) usando a capa embutida, sem decodificar o vídeo.

Os caminhos absolutos (`/home/rud/...`) são da minha máquina: troque pelos seus.
